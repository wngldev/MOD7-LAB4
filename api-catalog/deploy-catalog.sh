#!/bin/bash
# ============================================================
# deploy-catalog.sh — Deploy API Catalog to S3
# ============================================================
set -euo pipefail

# Load configuration
source config.env

echo "📋 Deploying API Catalog..."
echo "   Bucket: ${CATALOG_BUCKET_NAME}"
echo "   Region: ${AWS_REGION}"
echo "   Students: ${NUM_STUDENTS}"

# ── Step 1: Create S3 bucket ──
echo "📌 Creating S3 bucket..."
if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$CATALOG_BUCKET_NAME" \
    --region "$AWS_REGION" \
    --no-cli-pager 2>/dev/null || echo "⚠️  Bucket already exists (OK)"
else
  aws s3api create-bucket \
    --bucket "$CATALOG_BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" \
    --no-cli-pager 2>/dev/null || echo "⚠️  Bucket already exists (OK)"
fi

# ── Step 2: Disable Block Public Access ──
echo "📌 Configuring public access..."
aws s3api put-public-access-block \
  --bucket "$CATALOG_BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false \
  --no-cli-pager

# ── Step 3: Enable Static Website Hosting ──
echo "📌 Enabling Static Website Hosting..."
aws s3 website "s3://${CATALOG_BUCKET_NAME}" \
  --index-document index.html \
  --error-document index.html

# ── Step 4: Configure CORS ──
echo "📌 Configuring CORS..."
aws s3api put-bucket-cors \
  --bucket "$CATALOG_BUCKET_NAME" \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3600
    }]
  }' \
  --no-cli-pager

# ── Step 5: Set Bucket Policy (public read) ──
echo "📌 Setting Bucket Policy..."
aws s3api put-bucket-policy \
  --bucket "$CATALOG_BUCKET_NAME" \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Sid\": \"PublicReadGetObject\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::${CATALOG_BUCKET_NAME}/*\"
    }]
  }" \
  --no-cli-pager

# ── Step 6: Download Swagger UI (if not exists) ──
if [ ! -f "frontend/swagger-ui/swagger-ui-bundle.js" ]; then
  echo "📌 Downloading Swagger UI..."
  SWAGGER_VERSION="5.17.14"
  SWAGGER_URL="https://unpkg.com/swagger-ui-dist@${SWAGGER_VERSION}"
  
  curl -sL "${SWAGGER_URL}/swagger-ui-bundle.js" -o frontend/swagger-ui/swagger-ui-bundle.js
  curl -sL "${SWAGGER_URL}/swagger-ui-standalone-preset.js" -o frontend/swagger-ui/swagger-ui-standalone-preset.js
  curl -sL "${SWAGGER_URL}/swagger-ui.css" -o frontend/swagger-ui/swagger-ui.css
  
  echo "✅ Swagger UI downloaded (v${SWAGGER_VERSION})"
else
  echo "✅ Swagger UI already exists"
fi

# ── Step 7: Generate manifest.json ──
echo "📌 Generating manifest.json..."
SUFFIXES="["
for i in $(seq -w 1 "$NUM_STUDENTS"); do
  [ "$i" != "01" ] && SUFFIXES+=","
  SUFFIXES+="\"${i}\""
done
SUFFIXES+="]"
echo "$SUFFIXES" > frontend/manifest.json
echo "✅ manifest.json created with $NUM_STUDENTS suffixes"

# ── Step 8: Upload frontend to S3 ──
echo "📌 Uploading frontend files..."
aws s3 sync frontend/ "s3://${CATALOG_BUCKET_NAME}/" \
  --delete \
  --no-cli-pager

# ── Step 9: Create catalog directories ──
echo "📌 Creating catalog directories..."
for i in $(seq -w 1 "$NUM_STUDENTS"); do
  aws s3api put-object \
    --bucket "$CATALOG_BUCKET_NAME" \
    --key "catalog/${i}/" \
    --no-cli-pager > /dev/null 2>&1
done

WEBSITE_URL="http://${CATALOG_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"

echo ""
echo "============================================================"
echo "✅ API Catalog deployed successfully!"
echo "============================================================"
echo ""
echo "📋 Catalog URL: ${WEBSITE_URL}"
echo "🪣 Bucket Name: ${CATALOG_BUCKET_NAME}"
echo "🌍 Region: ${AWS_REGION}"
echo "👥 Students: ${NUM_STUDENTS}"
echo ""
echo "📌 Share these with students:"
echo "   CATALOG_BUCKET=${CATALOG_BUCKET_NAME}"
echo "   Catalog URL=${WEBSITE_URL}"
echo ""
