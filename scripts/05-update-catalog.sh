#!/bin/bash
# ============================================================
# 05-update-catalog.sh — Update API Catalog in S3
# ============================================================
set -euo pipefail

echo "📋 Updating API Catalog..."

# Parameters (passed as environment variables)
# STATUS: "MOCK" | "IMPLEMENTADO" | "PRODUCCION"
# API_ID: API Gateway ID
# PROD_ENDPOINT: (optional) Production endpoint URL
# API_KEY_VALUE: (optional) API Key value

API_NAME="cuentas-api-${SUFFIX}"
FUNCTION_NAME="cuentas-lambda-${SUFFIX}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Determine status emoji and details ──
case "$STATUS" in
  "MOCK")
    STATUS_DISPLAY="🟡 MOCK"
    TEST_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/test"
    ;;
  "IMPLEMENTADO")
    STATUS_DISPLAY="🔵 IMPLEMENTADO"
    TEST_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/test"
    ;;
  "PRODUCCION")
    STATUS_DISPLAY="🟢 PRODUCCIÓN"
    TEST_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/test"
    ;;
esac

# ── Build metadata JSON ──
cat > /tmp/metadata.json << EOF
{
  "suffix": "${SUFFIX}",
  "apiName": "${API_NAME}",
  "status": "${STATUS_DISPLAY}",
  "statusCode": "${STATUS}",
  "version": "1.0.0",
  "cloud": "AWS",
  "cloudIcon": "☁️",
  "region": "${AWS_REGION}",
  "services": {
    "gateway": "Amazon API Gateway",
    "compute": "AWS Lambda",
    "catalog": "Amazon S3"
  },
  "stages": {
    "test": "${TEST_ENDPOINT:-null}",
    "prod": "${PROD_ENDPOINT:-null}"
  },
  "apiKeyRequired": $([ "$STATUS" = "PRODUCCION" ] && echo "true" || echo "false"),
  "timestamps": {
    "lastUpdated": "${TIMESTAMP}",
    "mockDeployedAt": $([ "$STATUS" = "MOCK" ] && echo "\"${TIMESTAMP}\"" || echo "null"),
    "lambdaDeployedAt": $([ "$STATUS" = "IMPLEMENTADO" ] && echo "\"${TIMESTAMP}\"" || echo "null"),
    "promotedToProdAt": $([ "$STATUS" = "PRODUCCION" ] && echo "\"${TIMESTAMP}\"" || echo "null")
  },
  "pipeline": {
    "provider": "GitHub Actions",
    "repository": "${GITHUB_REPOSITORY:-unknown}",
    "runId": "${GITHUB_RUN_ID:-unknown}"
  }
}
EOF

echo "📌 Metadata:"
cat /tmp/metadata.json

# ── Upload metadata to S3 ──
echo "📌 Uploading metadata to S3..."
aws s3 cp /tmp/metadata.json "s3://${CATALOG_BUCKET}/catalog/${SUFFIX}/metadata.json" \
  --content-type "application/json" \
  --no-cli-pager

# ── Upload OpenAPI spec to S3 ──
if [ -f /tmp/openapi-export.json ]; then
  echo "📌 Uploading OpenAPI spec to S3..."
  aws s3 cp /tmp/openapi-export.json "s3://${CATALOG_BUCKET}/catalog/${SUFFIX}/openapi.json" \
    --content-type "application/json" \
    --no-cli-pager
fi

echo "✅ Catalog updated: ${STATUS_DISPLAY} for suffix ${SUFFIX}"
