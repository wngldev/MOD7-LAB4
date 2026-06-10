#!/bin/bash
# ============================================================
# 04-promote-prod.sh — Promote to Production
# ============================================================
set -euo pipefail

echo "🟠 [Pipeline 3] Promoting to production..."

API_NAME="cuentas-api-${SUFFIX}"
FUNCTION_NAME="cuentas-lambda-${SUFFIX}"
STAGE_NAME="prod"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ── Step 1: Get current test alias version ──
echo "📌 Getting version from alias 'test'..."
TEST_VERSION=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "test" \
  --query 'FunctionVersion' --output text \
  --no-cli-pager)

echo "✅ Test alias points to version: ${TEST_VERSION}"

# ── Step 2: Create or update alias 'prod' ──
echo "📌 Configuring alias 'prod' → version ${TEST_VERSION}..."
if aws lambda get-alias --function-name "$FUNCTION_NAME" --name "prod" --no-cli-pager 2>/dev/null; then
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "prod" \
    --function-version "$TEST_VERSION" \
    --no-cli-pager
else
  aws lambda create-alias \
    --function-name "$FUNCTION_NAME" \
    --name "prod" \
    --function-version "$TEST_VERSION" \
    --no-cli-pager
fi

echo "✅ Alias 'prod' → version ${TEST_VERSION}"

# ── Step 3: Get API ID ──
API_ID=$(aws apigateway get-rest-apis --limit 500 \
  --query "items[?name=='${API_NAME}'].id" \
  --output text --no-cli-pager)

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
  echo "❌ Error: Could not find API with name ${API_NAME}"
  exit 1
fi
echo "✅ API ID: ${API_ID}"

# ── Step 4: Update integration for prod alias ──
RESOURCES=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items' --output json --no-cli-pager)

RESOURCE_ID=$(echo "$RESOURCES" | python3 -c "
import sys, json
items = json.load(sys.stdin)
target = None
for item in items:
    if 'cuentas' in item.get('path', ''):
        target = item['id']
if target: print(target)
")

if [ -z "$RESOURCE_ID" ]; then
  echo "❌ Error: Could not find resource ID for path containing 'cuentas'"
  exit 1
fi
echo "✅ Resource ID: ${RESOURCE_ID}"

LAMBDA_URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}:prod/invocations"

aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "$LAMBDA_URI" \
  --no-cli-pager

# ── Step 5: Add Lambda permission for prod ──
aws lambda add-permission \
  --function-name "${FUNCTION_NAME}:prod" \
  --statement-id "apigateway-prod-${SUFFIX}-$(date +%s)" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/GET/clientes/*/cuentas" \
  --no-cli-pager 2>/dev/null || echo "⚠️  Permission already exists (OK)"

# ── Step 6: Enable API Key requirement on ALL methods ──
echo "📌 Enabling API Key requirement on production for all methods..."
# Obtenemos la lista de métodos configurados para este recurso
METHODS_IN_API=$(echo "$RESOURCES" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for item in items:
    if 'cuentas' in item.get('path', ''):
        print(' '.join(item.get('resourceMethods', {}).keys()))
        break
")

for METHOD in $METHODS_IN_API; do
  if [ "$METHOD" != "OPTIONS" ]; then
    echo "🔐 Setting API Key Required = true for ${METHOD}..."
    aws apigateway update-method \
      --rest-api-id "$API_ID" \
      --resource-id "$RESOURCE_ID" \
      --http-method "$METHOD" \
      --patch-operations op=replace,path=/apiKeyRequired,value=true \
      --no-cli-pager
  fi
done

# ── Step 7: Deploy stage prod ──
echo "📌 Deploying stage '${STAGE_NAME}'..."
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --description "Production deployment with API Key" \
  --no-cli-pager

# ── Step 8: Create or Reuse Usage Plan + API Key ──
echo "📌 Checking for existing Usage Plan 'plan-${SUFFIX}'..."
USAGE_PLAN_ID=$(aws apigateway get-usage-plans --limit 500 --query "items[?name=='plan-${SUFFIX}'].id" --output text --no-cli-pager)

if [ -z "$USAGE_PLAN_ID" ] || [ "$USAGE_PLAN_ID" == "None" ]; then
  echo "🆕 Creating new Usage Plan..."
  USAGE_PLAN_ID=$(aws apigateway create-usage-plan \
    --name "plan-${SUFFIX}" \
    --description "Usage plan for cuentas-api-${SUFFIX}" \
    --throttle burstLimit=5,rateLimit=2 \
    --quota limit=1000,period=DAY \
    --api-stages apiId="${API_ID}",stage="${STAGE_NAME}" \
    --query 'id' --output text \
    --no-cli-pager)
else
  echo "♻️  Reusing existing Usage Plan (ID: ${USAGE_PLAN_ID})..."
  # Asegurar que el plan esté vinculado a este API/Stage
  aws apigateway update-usage-plan \
    --usage-plan-id "$USAGE_PLAN_ID" \
    --patch-operations op=add,path=/apiStages,value="${API_ID}:${STAGE_NAME}" \
    --no-cli-pager 2>/dev/null || echo "⚠️  Stage already linked to plan (OK)"
fi

echo "📌 Checking for existing API Key 'key-${SUFFIX}'..."
API_KEY_ID=$(aws apigateway get-api-keys --limit 500 --query "items[?name=='key-${SUFFIX}'].id" --output text --no-cli-pager)

if [ -z "$API_KEY_ID" ] || [ "$API_KEY_ID" == "None" ]; then
  echo "🆕 Creating new API Key..."
  API_KEY_ID=$(aws apigateway create-api-key \
    --name "key-${SUFFIX}" \
    --enabled \
    --query 'id' --output text \
    --no-cli-pager)
else
  echo "♻️  Reusing existing API Key (ID: ${API_KEY_ID})..."
fi

API_KEY_VALUE=$(aws apigateway get-api-key \
  --api-key "$API_KEY_ID" \
  --include-value \
  --query 'value' --output text \
  --no-cli-pager)

# Vincular Key al Plan (si no está ya vinculada)
aws apigateway create-usage-plan-key \
  --usage-plan-id "$USAGE_PLAN_ID" \
  --key-id "$API_KEY_ID" \
  --key-type "API_KEY" \
  --no-cli-pager 2>/dev/null || echo "⚠️  Key already linked to plan (OK)"

PROD_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE_NAME}"

echo "✅ Production endpoint: ${PROD_ENDPOINT}"
echo "🔐 API Key: ${API_KEY_VALUE}"

# ── Export for catalog update ──
echo "API_ID=${API_ID}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "PROD_ENDPOINT=${PROD_ENDPOINT}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "API_KEY_VALUE=${API_KEY_VALUE}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "USAGE_PLAN_ID=${USAGE_PLAN_ID}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "API_KEY_ID=${API_KEY_ID}" >> "$GITHUB_ENV" 2>/dev/null || true

# ── Step 9: Export OpenAPI from prod stage ──
aws apigateway get-export \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" \
  --export-type oas30 \
  --accepts application/json \
  --no-cli-pager \
  /tmp/openapi-export.json

echo "⏳ Waiting for API Key propagation (120s)..."
echo "💡 Tip: API Gateway sometimes takes up to 2 minutes to propagate API Key changes."
sleep 120

echo "🟠 [Pipeline 3] Production promotion completed!"
