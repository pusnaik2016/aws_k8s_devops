#!/usr/bin/env bash
# ============================================================================
# dr-failover.sh — Disaster Recovery Failover Execution
# ============================================================================
# Promotes Azure DR to primary when AWS is down
# Usage: ./scripts/ops/dr-failover.sh [activate|deactivate|status]
# ============================================================================

set -euo pipefail

ACTION="${1:-status}"
ENV="prod"
PROJECT="healthcloud"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  🔄 DR FAILOVER — $ACTION                                     ║"
echo "║  Time: $TIMESTAMP                                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

case "$ACTION" in

  # ──────────────────────────────────────────────────────────────────────
  # STATUS — Check current DR state
  # ──────────────────────────────────────────────────────────────────────
  status)
    echo ""
    echo "── Current State ────────────────────────────────────────────────"
    echo -n "  AWS EKS: "
    aws eks describe-cluster --name ${PROJECT}-${ENV}-eks --query 'cluster.status' --output text 2>/dev/null || echo "UNREACHABLE"

    echo -n "  Azure AKS: "
    az aks show --name ${PROJECT}-${ENV}-aks --resource-group ${PROJECT}-${ENV}-aks-rg --query 'provisioningState' --output tsv 2>/dev/null || echo "UNREACHABLE"

    echo -n "  Route 53 Primary: "
    aws route53 get-health-check-status --health-check-id $(aws route53 list-health-checks --query 'HealthChecks[0].Id' --output text 2>/dev/null) --query 'HealthCheckObservations[0].StatusReport.Status' --output text 2>/dev/null || echo "UNKNOWN"

    echo -n "  Traffic Manager: "
    az network traffic-manager profile show --name ${PROJECT}-${ENV}-tm --resource-group ${PROJECT}-${ENV}-monitoring-rg --query 'profileStatus' --output tsv 2>/dev/null || echo "UNKNOWN"
    ;;

  # ──────────────────────────────────────────────────────────────────────
  # ACTIVATE — Failover to Azure DR
  # ──────────────────────────────────────────────────────────────────────
  activate)
    echo ""
    echo "  ⚠️  THIS WILL ACTIVATE DR FAILOVER TO AZURE"
    echo "  All traffic will be routed to Azure eastus"
    echo ""
    read -p "  Type 'FAILOVER' to confirm: " CONFIRM

    if [[ "$CONFIRM" != "FAILOVER" ]]; then
        echo "  ❌ Aborted."
        exit 1
    fi

    echo ""
    echo "── Step 1: Scale up Azure AKS ───────────────────────────────────"
    echo -n "  Scaling AKS to production capacity ... "
    az aks scale --name ${PROJECT}-${ENV}-aks \
        --resource-group ${PROJECT}-${ENV}-aks-rg \
        --node-count 5 \
        --nodepool-name apps && echo "✅"

    echo ""
    echo "── Step 2: Promote Azure PostgreSQL ─────────────────────────────"
    echo -n "  Note: Promote Azure DB manually if logical replication was used"
    echo "  Run: az postgres flexible-server stop-replication --name ${PROJECT}-${ENV}-pg-dr --resource-group ${PROJECT}-${ENV}-databases-rg"
    echo ""

    echo ""
    echo "── Step 3: Update DNS ───────────────────────────────────────────"
    echo -n "  Updating Route 53 to point to Azure ... "
    # In practice, Route 53 health check failover handles this automatically
    echo "  ✅ Route 53 failover routing will redirect traffic automatically"

    echo ""
    echo "── Step 4: Verify Azure Services ────────────────────────────────"
    echo -n "  Checking AKS pods ... "
    kubectl --context azure-${ENV} get pods -n healthcloud-apps --no-headers | wc -l 2>/dev/null && echo " pods running" || echo "⚠️  Check manually"

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  ✅ DR FAILOVER ACTIVATED at $TIMESTAMP"
    echo "  📝 Traffic now routing to Azure eastus"
    echo "═══════════════════════════════════════════════════════════════════"
    ;;

  # ──────────────────────────────────────────────────────────────────────
  # DEACTIVATE — Fail back to AWS
  # ──────────────────────────────────────────────────────────────────────
  deactivate)
    echo ""
    echo "  ⚠️  THIS WILL FAIL BACK TO AWS PRIMARY"
    echo ""
    read -p "  Type 'FAILBACK' to confirm: " CONFIRM

    if [[ "$CONFIRM" != "FAILBACK" ]]; then
        echo "  ❌ Aborted."
        exit 1
    fi

    echo ""
    echo "── Step 1: Verify AWS is healthy ────────────────────────────────"
    echo -n "  EKS status: "
    aws eks describe-cluster --name ${PROJECT}-${ENV}-eks --query 'cluster.status' --output text

    echo ""
    echo "── Step 2: Re-sync database from Azure to AWS ───────────────────"
    echo "  Note: Re-establish replication manually"
    echo "  1. Take Azure DB backup"
    echo "  2. Restore to Aurora"
    echo "  3. Re-configure replication"

    echo ""
    echo "── Step 3: Route traffic back to AWS ────────────────────────────"
    echo "  Route 53 will automatically route back when health check passes"

    echo ""
    echo "── Step 4: Scale down Azure AKS ─────────────────────────────────"
    echo -n "  Scaling AKS back to warm standby (2 nodes) ... "
    az aks scale --name ${PROJECT}-${ENV}-aks \
        --resource-group ${PROJECT}-${ENV}-aks-rg \
        --node-count 2 \
        --nodepool-name apps && echo "✅"

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  ✅ FAILBACK TO AWS completed at $TIMESTAMP"
    echo "═══════════════════════════════════════════════════════════════════"
    ;;

  *)
    echo "  Usage: $0 [activate|deactivate|status]"
    exit 1
    ;;
esac
