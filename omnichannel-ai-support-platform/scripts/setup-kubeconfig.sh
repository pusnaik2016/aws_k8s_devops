#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Setup kubeconfig + Cluster Add-ons — OmniPresenseAI
# ─────────────────────────────────────────────────────────────
# Configures kubectl and installs required Helm charts:
#   1. Configures kubectl for the EKS cluster
#   2. Installs KEDA (event-driven autoscaler)
#   3. Verifies AWS Load Balancer Controller (deployed via Terraform)
#   4. Verifies cluster connectivity and namespaces
#
# Usage:
#   chmod +x scripts/setup-kubeconfig.sh
#   ./scripts/setup-kubeconfig.sh [environment]
#
# Arguments:
#   environment   prod (default) or staging
#
# Prerequisites:
#   - AWS CLI v2 configured
#   - kubectl installed
#   - helm installed
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────

ENVIRONMENT="${1:-prod}"
PROJECT_NAME="omnipresense-ai"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
AWS_REGION="${AWS_REGION:-us-east-1}"
KEDA_NAMESPACE="keda"
KEDA_VERSION="2.13.0"

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
echo "  OmniPresenseAI — Cluster Setup (${ENVIRONMENT})"
echo "═══════════════════════════════════════════════════════"
echo ""

for cmd in aws kubectl helm; do
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "${cmd} not found. Please install it first."
        exit 1
    fi
done

log_info "Cluster:     ${CLUSTER_NAME}"
log_info "Region:      ${AWS_REGION}"
log_info "Environment: ${ENVIRONMENT}"
echo ""

# ─── 1. Configure kubeconfig ────────────────────────────────

log_info "Configuring kubectl for EKS cluster: ${CLUSTER_NAME}"

aws eks update-kubeconfig \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --alias "${CLUSTER_NAME}"

log_ok "kubeconfig updated"

# Verify connectivity
log_info "Verifying cluster connectivity..."
if kubectl cluster-info &>/dev/null; then
    log_ok "Connected to cluster"
    kubectl get nodes -o wide
else
    log_error "Cannot connect to cluster. Check IAM permissions and VPN."
    exit 1
fi

echo ""

# ─── 2. Install KEDA ────────────────────────────────────────

log_info "Installing KEDA v${KEDA_VERSION}..."

# Add KEDA Helm repo
helm repo add kedacore https://kedacore.github.io/charts 2>/dev/null || true
helm repo update

# Check if KEDA is already installed
if helm list -n "${KEDA_NAMESPACE}" 2>/dev/null | grep -q keda; then
    INSTALLED_VERSION=$(helm list -n "${KEDA_NAMESPACE}" -o json | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['chart'])" 2>/dev/null || echo "unknown")
    log_warn "KEDA already installed: ${INSTALLED_VERSION}"
    log_info "Upgrading to v${KEDA_VERSION}..."
    helm upgrade keda kedacore/keda \
        --namespace "${KEDA_NAMESPACE}" \
        --version "${KEDA_VERSION}" \
        --wait \
        --timeout 5m
else
    kubectl create namespace "${KEDA_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    helm install keda kedacore/keda \
        --namespace "${KEDA_NAMESPACE}" \
        --version "${KEDA_VERSION}" \
        --set serviceAccount.create=true \
        --wait \
        --timeout 5m
fi

log_ok "KEDA installed/upgraded"

# Verify KEDA pods
log_info "Verifying KEDA pods..."
kubectl get pods -n "${KEDA_NAMESPACE}"
echo ""

# ─── 3. Verify AWS Load Balancer Controller ──────────────────

log_info "Verifying AWS Load Balancer Controller..."

if kubectl get deployment -n kube-system aws-load-balancer-controller &>/dev/null; then
    LB_READY=$(kubectl get deployment -n kube-system aws-load-balancer-controller \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "${LB_READY}" -gt 0 ]; then
        log_ok "AWS Load Balancer Controller is running (${LB_READY} replicas)"
    else
        log_warn "AWS Load Balancer Controller exists but has 0 ready replicas"
        kubectl describe deployment -n kube-system aws-load-balancer-controller
    fi
else
    log_warn "AWS Load Balancer Controller not found."
    log_warn "It should be deployed via Terraform (compute module)."
    log_warn "Run 'terraform apply' in terraform/envs/${ENVIRONMENT}/ first."
fi

echo ""

# ─── 4. Verify Namespace and Resources ──────────────────────

log_info "Checking omni-ai namespace..."

if kubectl get namespace omni-ai &>/dev/null; then
    log_ok "Namespace 'omni-ai' exists"
    echo ""
    log_info "Current resources in omni-ai:"
    kubectl get all -n omni-ai 2>/dev/null || log_warn "No resources deployed yet"
else
    log_warn "Namespace 'omni-ai' not found. Deploy K8s manifests:"
    log_warn "  kubectl apply -k k8s/overlays/${ENVIRONMENT}/"
fi

echo ""

# ─── Summary ────────────────────────────────────────────────

echo "═══════════════════════════════════════════════════════"
echo "  Cluster Setup Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  ✓ kubeconfig configured for: ${CLUSTER_NAME}"
echo "  ✓ KEDA v${KEDA_VERSION} installed"
echo "  ✓ AWS LB Controller verified"
echo ""
echo "  Next Steps:"
echo "    1. kubectl apply -k k8s/overlays/${ENVIRONMENT}/"
echo "    2. kubectl get pods -n omni-ai -w"
echo "    3. python scripts/seed-knowledge-base.py"
echo ""
