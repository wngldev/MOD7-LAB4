#!/bin/bash
# ============================================================
# 02-deploy-lambda-test.sh — Deploy Lambda + Version + Alias test
# ============================================================
set -euo pipefail

echo "🟢 [Pipeline 2] Deploying Lambda function..."

FUNCTION_NAME="cuentas-lambda-${SUFFIX}"
ALIAS_NAME="test"
ZIP_FILE="/tmp/function.zip"

# ── Step 1: Package Lambda code ──
echo "📌 Packaging Lambda function..."
cd implementation
zip -r "$ZIP_FILE" src/
cd ..

# ── Step 2: Create or Update Lambda function ──
echo "📌 Checking if function '${FUNCTION_NAME}' exists..."
if aws lambda get-function --function-name "$FUNCTION_NAME" --no-cli-pager 2>/dev/null; then
  echo "♻️  Function exists. Updating code..."
  VERSION=$(aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://${ZIP_FILE}" \
    --publish \
    --query 'Version' --output text \
    --no-cli-pager)

  echo "⏳ Waiting for function update..."
  aws lambda wait function-updated-v2 --function-name "$FUNCTION_NAME"
else
  echo "🆕 Creating new Lambda function..."
  VERSION=$(aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime nodejs24.x \
    --handler src/index.handler \
    --role "$LAMBDA_ROLE_ARN" \
    --zip-file "fileb://${ZIP_FILE}" \
    --timeout 10 \
    --memory-size 128 \
    --publish \
    --query 'Version' --output text \
    --no-cli-pager)

  echo "⏳ Waiting for function to be active..."
  aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME"
fi

echo "✅ Deployed version: ${VERSION}"

# ── Step 3: (Merged into Step 2 with --publish) ──
# El comando publish-version ya no es necesario por separado si usamos --publish arriba
# para asegurar que siempre incremente la versión.

# ── Step 4: Create or update alias 'test' ──
echo "📌 Configuring alias '${ALIAS_NAME}' → version ${VERSION}..."
if aws lambda get-alias --function-name "$FUNCTION_NAME" --name "$ALIAS_NAME" --no-cli-pager 2>/dev/null; then
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "$ALIAS_NAME" \
    --function-version "$VERSION" \
    --no-cli-pager
else
  aws lambda create-alias \
    --function-name "$FUNCTION_NAME" \
    --name "$ALIAS_NAME" \
    --function-version "$VERSION" \
    --no-cli-pager
fi

echo "✅ Alias '${ALIAS_NAME}' → version ${VERSION}"

# ── Step 5: Export for next steps ──
echo "LAMBDA_VERSION=${VERSION}" >> "$GITHUB_ENV" 2>/dev/null || true
echo "FUNCTION_NAME=${FUNCTION_NAME}" >> "$GITHUB_ENV" 2>/dev/null || true

echo "🟢 [Pipeline 2] Lambda deployment completed successfully!"
