#!/usr/bin/env bash
# ============================================================================
# setup-backends.sh — Initialize Terraform State Backends
# ============================================================================
# Creates S3 buckets + DynamoDB tables (AWS) and Storage Accounts (Azure)
# Usage: ./scripts/ops/setup-backends.sh [environment]
# ============================================================================

set -euo pipefail

ENV="${1:-dev}"
PROJECT="healthcloud"
AWS_REGION="us-east-1"
AZURE_REGION="eastus"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  🗄️  Setting up Terraform state backends for: $ENV              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# ──────────────────────────────────────────────────────────────────────────
# AWS — S3 + DynamoDB
# ──────────────────────────────────────────────────────────────────────────
echo ""
echo "── AWS State Backend ────────────────────────────────────────────"

BUCKET="${PROJECT}-${ENV}-terraform-state"
TABLE="${PROJECT}-${ENV}-terraform-locks"

echo -n "  Creating S3 bucket: $BUCKET ... "
aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null && echo "✅" || echo "ℹ️  Already exists"

echo -n "  Enabling versioning ... "
aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled && echo "✅"

echo -n "  Enabling encryption ... "
aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}, "BucketKeyEnabled": true}]
    }' && echo "✅"

echo -n "  Blocking public access ... "
aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true && echo "✅"

echo -n "  Creating DynamoDB table: $TABLE ... "
aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION" 2>/dev/null && echo "✅" || echo "ℹ️  Already exists"

# ──────────────────────────────────────────────────────────────────────────
# Azure — Storage Account + Container
# ──────────────────────────────────────────────────────────────────────────
echo ""
echo "── Azure State Backend ──────────────────────────────────────────"

RG="${PROJECT}-${ENV}-terraform-rg"
SA="${PROJECT}${ENV}tfstate"  # No hyphens in storage account names

echo -n "  Creating resource group: $RG ... "
az group create --name "$RG" --location "$AZURE_REGION" --output none 2>/dev/null && echo "✅"

echo -n "  Creating storage account: $SA ... "
az storage account create \
    --name "$SA" \
    --resource-group "$RG" \
    --location "$AZURE_REGION" \
    --sku Standard_LRS \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none 2>/dev/null && echo "✅" || echo "ℹ️  Already exists"

echo -n "  Creating blob container: tfstate ... "
az storage container create \
    --name tfstate \
    --account-name "$SA" \
    --output none 2>/dev/null && echo "✅" || echo "ℹ️  Already exists"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✅ State backends ready for environment: $ENV"
echo "═══════════════════════════════════════════════════════════════════"
