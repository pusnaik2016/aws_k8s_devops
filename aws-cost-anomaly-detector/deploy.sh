#!/usr/bin/env bash
# deploy.sh — One-command deployment for the AWS Cost Anomaly Detector
# Usage: ./deploy.sh [plan|apply|destroy]
set -euo pipefail

###############################################################################
# Color helpers
###############################################################################
GREEN='\033[0;32m'  YELLOW='\033[1;33m'  RED='\033[0;31m'  NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

COMMAND="${1:-apply}"

###############################################################################
# Pre-flight checks
###############################################################################
info "Running pre-flight checks..."

command -v terraform >/dev/null 2>&1 || error "Terraform not found. Install from https://terraform.io/downloads"
command -v aws       >/dev/null 2>&1 || error "AWS CLI not found. Install from https://aws.amazon.com/cli"

TF_VERSION=$(terraform version -json | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])")
info "Terraform version: $TF_VERSION"

# Check AWS credentials
AWS_IDENTITY=$(aws sts get-caller-identity --query "{Account:Account,Arn:Arn}" --output json 2>/dev/null) \
  || error "AWS credentials not configured. Run: aws configure"

AWS_ACCOUNT=$(echo "$AWS_IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])")
AWS_ARN=$(echo "$AWS_IDENTITY"     | python3 -c "import sys,json; print(json.load(sys.stdin)['Arn'])")

info "AWS Account : $AWS_ACCOUNT"
info "AWS Identity: $AWS_ARN"

# Verify terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  warn "terraform.tfvars not found!"
  echo ""
  echo "  Create it by running:"
  echo "    cp terraform.tfvars.example terraform.tfvars"
  echo "    vim terraform.tfvars   # Set alert_email and optionally other values"
  echo ""
  error "Aborting. Please create terraform.tfvars first."
fi

# Create Lambda dist directory if it doesn't exist
mkdir -p modules/cost_analyzer/lambda/dist

###############################################################################
# Terraform init
###############################################################################
info "Initialising Terraform..."
terraform init -upgrade

###############################################################################
# Terraform action
###############################################################################
case "$COMMAND" in
  plan)
    info "Running Terraform plan..."
    terraform plan -out=tfplan
    ;;

  apply)
    info "Running Terraform apply..."
    terraform apply -auto-approve

    echo ""
    info "════════════════════════════════════════════════════════════"
    info "                  DEPLOYMENT COMPLETE"
    info "════════════════════════════════════════════════════════════"
    echo ""
    warn "IMPORTANT: Check your email and CONFIRM the SNS subscription!"
    warn "  → The alert email will arrive from AWS Notifications"
    warn "  → Without confirmation, no alerts will be delivered."
    echo ""
    terraform output deployment_summary
    ;;

  destroy)
    warn "You are about to DESTROY all resources. This cannot be undone."
    read -p "Type 'yes' to confirm: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      info "Destroy cancelled."
      exit 0
    fi
    info "Destroying all resources..."
    terraform destroy -auto-approve
    info "All resources destroyed."
    ;;

  *)
    error "Unknown command: $COMMAND. Use: plan | apply | destroy"
    ;;
esac
