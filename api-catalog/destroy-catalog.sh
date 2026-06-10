#!/bin/bash
# ============================================================
# destroy-catalog.sh — Destroy API Catalog
# ============================================================
set -euo pipefail

source config.env

echo "🔴 Destroying API Catalog..."

echo "📌 Emptying bucket..."
aws s3 rm "s3://${CATALOG_BUCKET_NAME}" --recursive --no-cli-pager 2>/dev/null || true

echo "📌 Deleting bucket..."
aws s3api delete-bucket --bucket "$CATALOG_BUCKET_NAME" --no-cli-pager 2>/dev/null || true

echo "📌 Deleting Lambda role..."
aws iam detach-role-policy \
  --role-name lab-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  2>/dev/null || true
aws iam delete-role --role-name lab-lambda-role 2>/dev/null || true

echo "✅ API Catalog destroyed!"
