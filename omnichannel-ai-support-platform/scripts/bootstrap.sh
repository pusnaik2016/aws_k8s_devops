#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Bootstrap Script — OmniPresenseAI
# ─────────────────────────────────────────────────────────────
# Creates the following AWS resources for initial setup:
#   1. S3 bucket for Terraform state backend
#   2. DynamoDB table for Terraform state locking
#   3. ECR repositories for microservice container images
#
# Usage:
#   chmod +x scripts/bootstrap.sh
#   ./scripts/bootstrap.sh
#
# Prerequisites:
#   - AWS CLI v2 configured with admin permissions
#   - jq installed
#
# This script is idempotent — safe to re-run.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────

PROJECT_NAME="omnipresense-ai"
AWS_REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="${PROJECT_NAME}-terraform-state"
LOCK_TABLE="${PROJECT_NAME}-terraform-locks"
ECR_REPOS=(
    "${PROJECT_NAME}/chat-service"
    "${PROJECT_NAME}/analytics-service"
)

# ─── Colors ──────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Pre-flight Checks ──────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  OmniPresenseAI — AWS Bootstrap"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check AWS CLI
if ! command -v aws &>/dev/null; then
    log_error "AWS CLI not found. Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
fi

# Check AWS credentials
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || {
    log_error "AWS credentials not configured. Run: aws configure"
    exit 1
}
log_info "AWS Account: ${ACCOUNT_ID}"
log_info "AWS Region:  ${AWS_REGION}"
echo ""

# ─── 1. S3 Terraform State Bucket ───────────────────────────

log_info "Creating S3 bucket for Terraform state: ${STATE_BUCKET}"

if aws s3api head-bucket --bucket "${STATE_BUCKET}" 2>/dev/null; then
    log_ok "Bucket already exists: ${STATE_BUCKET}"
else
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${STATE_BUCKET}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${STATE_BUCKET}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    log_ok "Created bucket: ${STATE_BUCKET}"
fi

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket "${STATE_BUCKET}" \
    --versioning-configuration Status=Enabled
log_ok "Versioning enabled on ${STATE_BUCKET}"

# Enable server-side encryption
aws s3api put-bucket-encryption \
    --bucket "${STATE_BUCKET}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "aws:kms"
            },
            "BucketKeyEnabled": true
        }]
    }'
log_ok "KMS encryption enabled on ${STATE_BUCKET}"

# Block public access
aws s3api put-public-access-block \
    --bucket "${STATE_BUCKET}" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'
log_ok "Public access blocked on ${STATE_BUCKET}"

echo ""

# ─── 2. DynamoDB Lock Table ─────────────────────────────────

log_info "Creating DynamoDB table for state locking: ${LOCK_TABLE}"

if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" &>/dev/null; then
    log_ok "Table already exists: ${LOCK_TABLE}"
else
    aws dynamodb create-table \
        --table-name "${LOCK_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}" \
        --tags Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=bootstrap

    log_info "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "${LOCK_TABLE}" --region "${AWS_REGION}"
    log_ok "Created table: ${LOCK_TABLE}"
fi

echo ""

# ─── 3. ECR Repositories ────────────────────────────────────

log_info "Creating ECR repositories..."

for repo in "${ECR_REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names "${repo}" --region "${AWS_REGION}" &>/dev/null; then
        log_ok "Repository already exists: ${repo}"
    else
        aws ecr create-repository \
            --repository-name "${repo}" \
            --region "${AWS_REGION}" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=KMS \
            --image-tag-mutability IMMUTABLE \
            --tags Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=bootstrap

        log_ok "Created repository: ${repo}"
    fi

    # Set lifecycle policy (keep last 10 images)
    aws ecr put-lifecycle-policy \
        --repository-name "${repo}" \
        --region "${AWS_REGION}" \
        --lifecycle-policy-text '{
            "rules": [{
                "rulePriority": 1,
                "description": "Keep last 10 images",
                "selection": {
                    "tagStatus": "any",
                    "countType": "imageCountMoreThan",
                    "countNumber": 10
                },
                "action": { "type": "expire" }
            }]
        }' >/dev/null

    log_ok "Lifecycle policy set for: ${repo}"
done

echo ""

# ─── Summary ────────────────────────────────────────────────

echo "═══════════════════════════════════════════════════════"
echo "  Bootstrap Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Resources Created:"
echo "    ✓ S3 Bucket:     ${STATE_BUCKET}"
echo "    ✓ DynamoDB Table: ${LOCK_TABLE}"
for repo in "${ECR_REPOS[@]}"; do
    echo "    ✓ ECR Repo:      ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${repo}"
done
echo ""
echo "  Next Steps:"
echo "    1. cd terraform/envs/prod"
echo "    2. cp terraform.tfvars.example terraform.tfvars"
echo "    3. terraform init"
echo "    4. terraform plan -out=tfplan"
echo "    5. terraform apply tfplan"
echo ""
