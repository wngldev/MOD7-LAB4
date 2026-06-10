#!/bin/bash
# ============================================================
# 99-cleanup.sh — Cleanup all AWS resources
# ============================================================
set -euo pipefail

# Verificar variables de entorno
if [ -z "${SUFFIX:-}" ]; then
  echo "❌ Error: La variable de entorno SUFFIX no está definida."
  exit 1
fi

if [ -z "${CATALOG_BUCKET:-}" ]; then
  echo "⚠️  Advertencia: CATALOG_BUCKET no está definida. El paso de limpieza de S3 podría fallar."
fi

echo "🔴 Cleaning up all resources for suffix ${SUFFIX}..."

API_NAME="cuentas-api-${SUFFIX}"
FUNCTION_NAME="cuentas-lambda-${SUFFIX}"

# ── Step 1: Delete API Keys ──
echo "📌 Deleting API Keys 'key-${SUFFIX}'..."
API_KEY_IDS=$(aws apigateway get-api-keys --limit 500 \
  --query "items[?name=='key-${SUFFIX}'].id" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for KEY_ID in $API_KEY_IDS; do
  if [ -n "$KEY_ID" ] && [ "$KEY_ID" != "None" ]; then
    echo "  Deleting API Key: ${KEY_ID}"
    aws apigateway delete-api-key --api-key "$KEY_ID" --no-cli-pager 2>/dev/null || true
  fi
done

# ── Step 2: Delete API Gateways ──
echo "📌 Deleting API Gateways '${API_NAME}'..."
API_IDS=$(aws apigateway get-rest-apis --limit 500 \
  --query "items[?name=='${API_NAME}'].id" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for API_ID in $API_IDS; do
  if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    echo "  Deleting REST API: ${API_ID}"
    aws apigateway delete-rest-api --rest-api-id "$API_ID" --no-cli-pager 2>/dev/null || true
  fi
done

sleep 2

# ── Step 3: Delete Usage Plans ──
echo "📌 Deleting Usage Plans 'plan-${SUFFIX}'..."
PLAN_IDS=$(aws apigateway get-usage-plans --limit 500 \
  --query "items[?name=='plan-${SUFFIX}'].id" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for PLAN_ID in $PLAN_IDS; do
  if [ -n "$PLAN_ID" ] && [ "$PLAN_ID" != "None" ]; then
    echo "  Deleting Usage Plan: ${PLAN_ID}"
    aws apigateway delete-usage-plan --usage-plan-id "$PLAN_ID" --no-cli-pager || true
  fi
done

# ── Step 4: Delete Lambda aliases ──
echo "📌 Deleting Lambda aliases for ${FUNCTION_NAME}..."
for ALIAS in test prod; do
  aws lambda delete-alias \
    --function-name "$FUNCTION_NAME" \
    --name "$ALIAS" \
    --no-cli-pager 2>/dev/null || true
done

# ── Step 5: Delete Lambda versions ──
echo "📌 Deleting Lambda versions for ${FUNCTION_NAME}..."
VERSIONS=$(aws lambda list-versions-by-function \
  --function-name "$FUNCTION_NAME" \
  --query "Versions[?Version!='\$LATEST'].Version" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for VER in $VERSIONS; do
  if [ -n "$VER" ] && [ "$VER" != "None" ]; then
    echo "  Deleting Lambda Version: ${VER}"
    aws lambda delete-function \
      --function-name "$FUNCTION_NAME" \
      --qualifier "$VER" \
      --no-cli-pager 2>/dev/null || true
  fi
done

# ── Step 6: Delete Lambda function ──
echo "📌 Deleting Lambda function ${FUNCTION_NAME}..."
aws lambda delete-function \
  --function-name "$FUNCTION_NAME" \
  --no-cli-pager 2>/dev/null || true

# ── Step 7: Delete catalog files from S3 ──
if [ -n "${CATALOG_BUCKET:-}" ]; then
  echo "📌 Deleting catalog files from S3 bucket ${CATALOG_BUCKET}..."
  aws s3 rm "s3://${CATALOG_BUCKET}/catalog/${SUFFIX}/" \
    --recursive --no-cli-pager 2>/dev/null || true
fi

echo "✅ All resources cleaned up for suffix ${SUFFIX}!"
echo "🔴 Cleanup completed!"
