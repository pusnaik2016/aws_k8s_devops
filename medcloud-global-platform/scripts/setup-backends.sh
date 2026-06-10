#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# MedCloud — Initialize Terraform State Backends (all 3 clouds)
# ─────────────────────────────────────────────────────────────────────────────
# Run ONCE before first terraform init.
# Creates S3 bucket + DynamoDB (AWS), Storage Account (Azure), GCS bucket (GCP).
# Usage: ./scripts/setup-backends.sh <environment>
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ENV="${1:-dev}"
PROJECT="medcloud"
AWS_REGION="us-east-1"
AZURE_LOCATION="eastus"
AZURE_RG="medcloud-terraform-state-rg"
GCP_PROJECT="medcloud-global-${ENV}"

echo "═══════════════════════════════════════════════════════════════"
echo "  🏥 MedCloud — Terraform Backend Setup"
echo "  Environment: ${ENV}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ─── AWS: S3 + DynamoDB ─────────────────────────────────────────────────
echo "── Setting up AWS backend ──"

S3_BUCKET="${PROJECT}-terraform-state-${ENV}"
DYNAMO_TABLE="${PROJECT}-terraform-locks-${ENV}"

# Create S3 bucket
aws s3api create-bucket \
  --bucket "${S3_BUCKET}" \
  --region "${AWS_REGION}" \
  2>/dev/null || echo "  S3 bucket already exists"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "${S3_BUCKET}" \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "${S3_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}, "BucketKeyEnabled": true}]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket "${S3_BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name "${DYNAMO_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" \
  2>/dev/null || echo "  DynamoDB table already exists"

echo "  ✅ AWS: s3://${S3_BUCKET} + ${DYNAMO_TABLE}"

# ─── Azure: Storage Account ─────────────────────────────────────────────
echo "── Setting up Azure backend ──"

AZURE_SA="medcloudtfstate${ENV}"
AZURE_CONTAINER="tfstate"

# Create resource group
az group create \
  --name "${AZURE_RG}" \
  --location "${AZURE_LOCATION}" \
  --output none 2>/dev/null || true

# Create storage account
az storage account create \
  --name "${AZURE_SA}" \
  --resource-group "${AZURE_RG}" \
  --location "${AZURE_LOCATION}" \
  --sku Standard_GRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none 2>/dev/null || echo "  Storage account already exists"

# Create blob container
az storage container create \
  --name "${AZURE_CONTAINER}" \
  --account-name "${AZURE_SA}" \
  --output none 2>/dev/null || true

echo "  ✅ Azure: ${AZURE_SA}/${AZURE_CONTAINER}"

# ─── GCP: Cloud Storage ─────────────────────────────────────────────────
echo "── Setting up GCP backend ──"

GCS_BUCKET="${PROJECT}-terraform-state-gcp-${ENV}"

# Create GCS bucket
gcloud storage buckets create "gs://${GCS_BUCKET}" \
  --project="${GCP_PROJECT}" \
  --location="US" \
  --uniform-bucket-level-access \
  --public-access-prevention \
  2>/dev/null || echo "  GCS bucket already exists"

# Enable versioning
gcloud storage buckets update "gs://${GCS_BUCKET}" \
  --versioning

echo "  ✅ GCP: gs://${GCS_BUCKET}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ All backends created for environment: ${ENV}"
echo ""
echo "  To initialize Terraform:"
echo "    cd terraform/environments/${ENV}"
echo "    terraform init -backend-config=backend.hcl"
echo "═══════════════════════════════════════════════════════════════"
