#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# MedCloud Global — Daily Health Check Script
# ─────────────────────────────────────────────────────────────────────────────
# Runs automated health checks across all 3 cloud Kubernetes clusters.
# Usage: ./scripts/health-check.sh [--verbose]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

VERBOSE="${1:-}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTERS=("medcloud-aws" "medcloud-azure" "medcloud-gcp")
NAMESPACE="medcloud"
PASS=0
WARN=0
FAIL=0

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🏥 MedCloud Global — Daily Health Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ─── Function: Check cluster connectivity ────────────────────────────────
check_cluster() {
  local ctx=$1
  echo -e "${CYAN}── Cluster: $ctx ──${NC}"
  
  if ! kubectl --context="$ctx" cluster-info &>/dev/null; then
    echo -e "  ${RED}✗ UNREACHABLE${NC} — Cannot connect to cluster"
    ((FAIL++))
    return
  fi
  echo -e "  ${GREEN}✓${NC} Cluster reachable"
  ((PASS++))

  # Node status
  local unhealthy_nodes
  unhealthy_nodes=$(kubectl --context="$ctx" get nodes \
    --no-headers 2>/dev/null | grep -cv " Ready" || true)
  if [ "$unhealthy_nodes" -gt 0 ]; then
    echo -e "  ${RED}✗ $unhealthy_nodes unhealthy node(s)${NC}"
    ((FAIL++))
  else
    local total_nodes
    total_nodes=$(kubectl --context="$ctx" get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} All $total_nodes nodes Ready"
    ((PASS++))
  fi

  # Pod status in medcloud namespace
  local failing_pods
  failing_pods=$(kubectl --context="$ctx" -n "$NAMESPACE" get pods \
    --no-headers 2>/dev/null | grep -cvE "Running|Completed" || true)
  if [ "$failing_pods" -gt 0 ]; then
    echo -e "  ${RED}✗ $failing_pods pod(s) not Running${NC}"
    kubectl --context="$ctx" -n "$NAMESPACE" get pods \
      --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | head -5
    ((FAIL++))
  else
    local total_pods
    total_pods=$(kubectl --context="$ctx" -n "$NAMESPACE" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} All $total_pods pods Running"
    ((PASS++))
  fi

  # Pod restarts (last hour)
  local high_restarts
  high_restarts=$(kubectl --context="$ctx" -n "$NAMESPACE" get pods \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\n"}{end}{end}' \
    2>/dev/null | awk -F'\t' '$2 > 5 {print $1}' | head -5)
  if [ -n "$high_restarts" ]; then
    echo -e "  ${YELLOW}⚠ High restart count:${NC}"
    echo "$high_restarts" | while read -r pod; do echo "    - $pod"; done
    ((WARN++))
  else
    echo -e "  ${GREEN}✓${NC} No excessive pod restarts"
    ((PASS++))
  fi

  # ArgoCD application sync status
  local out_of_sync
  out_of_sync=$(kubectl --context="$ctx" -n argocd get applications \
    --no-headers 2>/dev/null | grep -cv "Synced" || true)
  if [ "$out_of_sync" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ $out_of_sync ArgoCD app(s) out of sync${NC}"
    ((WARN++))
  else
    echo -e "  ${GREEN}✓${NC} ArgoCD apps synced"
    ((PASS++))
  fi

  echo ""
}

# ─── Function: Check cross-cloud VPN tunnels ────────────────────────────
check_vpn() {
  echo -e "${CYAN}── Cross-Cloud VPN Status ──${NC}"
  
  # AWS VPN
  if command -v aws &>/dev/null; then
    local aws_vpn
    aws_vpn=$(aws ec2 describe-vpn-connections \
      --query 'VpnConnections[*].VgwTelemetry[*].Status' \
      --output text 2>/dev/null || echo "UNKNOWN")
    if echo "$aws_vpn" | grep -q "UP"; then
      echo -e "  ${GREEN}✓${NC} AWS VPN tunnels: UP"
      ((PASS++))
    else
      echo -e "  ${RED}✗ AWS VPN tunnels: $aws_vpn${NC}"
      ((FAIL++))
    fi
  fi

  # GCP VPN
  if command -v gcloud &>/dev/null; then
    local gcp_vpn
    gcp_vpn=$(gcloud compute vpn-tunnels list \
      --format='value(status)' 2>/dev/null | head -1 || echo "UNKNOWN")
    if [ "$gcp_vpn" = "ESTABLISHED" ]; then
      echo -e "  ${GREEN}✓${NC} GCP VPN tunnels: ESTABLISHED"
      ((PASS++))
    else
      echo -e "  ${YELLOW}⚠ GCP VPN tunnels: $gcp_vpn${NC}"
      ((WARN++))
    fi
  fi

  echo ""
}

# ─── Run all checks ─────────────────────────────────────────────────────
for cluster in "${CLUSTERS[@]}"; do
  check_cluster "$cluster"
done

check_vpn

# ─── Summary ────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}✓ PASS: $PASS${NC}  |  ${YELLOW}⚠ WARN: $WARN${NC}  |  ${RED}✗ FAIL: $FAIL${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo -e "\n${RED}❌ HEALTH CHECK FAILED — Investigate immediately${NC}"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo -e "\n${YELLOW}⚠️  HEALTH CHECK PASSED WITH WARNINGS${NC}"
  exit 0
else
  echo -e "\n${GREEN}✅ ALL HEALTH CHECKS PASSED${NC}"
  exit 0
fi
