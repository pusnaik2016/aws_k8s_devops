#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap Script — Initial Setup for EKS Retail Platform
# ─────────────────────────────────────────────────────────────────────────────
# Creates:
#   1. S3 bucket for Terraform state
#   2. DynamoDB table for state locking
#   3. Validates prerequisites
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
PROJECT_NAME="eks-retail"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="${PROJECT_NAME}-terraform-state"
LOCK_TABLE="${PROJECT_NAME}-terraform-locks"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       EKS Retail Platform — Bootstrap Script                ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Account:  ${ACCOUNT_ID}                                    ║"
echo "║  Region:   ${AWS_REGION}                                    ║"
echo "║  Bucket:   ${STATE_BUCKET}                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ─── Prerequisite Check ─────────────────────────────────────────────────────
echo "→ Checking prerequisites..."

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "  ✗ $1 not found. Please install it."
    exit 1
  fi
  echo "  ✓ $1 found"
}

check_cmd aws
check_cmd terraform
check_cmd kubectl
check_cmd helm
check_cmd jq

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  echo "  ✗ AWS credentials not configured"
  exit 1
fi
echo "  ✓ AWS credentials valid"
echo ""

# ─── Create S3 Bucket for Terraform State ────────────────────────────────────
echo "→ Creating Terraform state bucket: ${STATE_BUCKET}"
if aws s3api head-bucket --bucket "${STATE_BUCKET}" 2>/dev/null; then
  echo "  ✓ Bucket already exists"
else
  aws s3api create-bucket \
    --bucket "${STATE_BUCKET}" \
    --region "${AWS_REGION}" \
    $([ "${AWS_REGION}" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=${AWS_REGION}")

  # Enable versioning
  aws s3api put-bucket-versioning \
    --bucket "${STATE_BUCKET}" \
    --versioning-configuration Status=Enabled

  # Enable encryption
  aws s3api put-bucket-encryption \
    --bucket "${STATE_BUCKET}" \
    --server-side-encryption-configuration '{
      "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"},"BucketKeyEnabled": true}]
    }'

  # Block public access
  aws s3api put-public-access-block \
    --bucket "${STATE_BUCKET}" \
    --public-access-block-configuration '{
      "BlockPublicAcls": true,
      "IgnorePublicAcls": true,
      "BlockPublicPolicy": true,
      "RestrictPublicBuckets": true
    }'

  echo "  ✓ Bucket created with encryption + versioning"
fi
echo ""

# ─── Create DynamoDB Lock Table ──────────────────────────────────────────────
echo "→ Creating DynamoDB lock table: ${LOCK_TABLE}"
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" &>/dev/null; then
  echo "  ✓ Table already exists"
else
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}"

  aws dynamodb wait table-exists --table-name "${LOCK_TABLE}" --region "${AWS_REGION}"
  echo "  ✓ Lock table created"
fi
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓ Bootstrap Complete                                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Next Steps:                                                 ║"
echo "║    cd terraform/environments/dev                             ║"
echo "║    terraform init -backend-config=backend.hcl                ║"
echo "║    terraform plan -var-file=terraform.tfvars                 ║"
echo "║    terraform apply -var-file=terraform.tfvars                ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
