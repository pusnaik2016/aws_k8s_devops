#!/usr/bin/env bash
# ============================================================================
# health-check.sh — Cross-Cloud Health Check
# ============================================================================
# Checks EKS + AKS + databases + DNS health
# Usage: ./scripts/ops/health-check.sh [environment]
# ============================================================================

set -euo pipefail

ENV="${1:-prod}"
PROJECT="healthcloud"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  🏥 HealthCloud Cross-Cloud Health Check                        ║"
echo "║  Environment: $ENV                                              ║"
echo "║  Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

check() {
    local name=$1
    local cmd=$2
    echo -n "  [$name] ... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "✅ HEALTHY"
        ((PASS++))
    else
        echo "❌ UNHEALTHY"
        ((FAIL++))
    fi
}

echo "── AWS Primary (us-east-1) ──────────────────────────────────────"
check "EKS Cluster" "aws eks describe-cluster --name ${PROJECT}-${ENV}-eks --query 'cluster.status' --output text | grep -q ACTIVE"
check "Aurora DB" "aws rds describe-db-clusters --db-cluster-identifier ${PROJECT}-${ENV}-aurora-primary --query 'DBClusters[0].Status' --output text | grep -q available"
check "Redis" "aws elasticache describe-replication-groups --replication-group-id ${PROJECT}-${ENV}-redis --query 'ReplicationGroups[0].Status' --output text | grep -q available"
check "Route 53 HC" "aws route53 get-health-check-status --health-check-id \$(aws route53 list-health-checks --query 'HealthChecks[0].Id' --output text) --query 'HealthCheckObservations[0].StatusReport.Status' --output text | grep -q Success"
check "S3 PHI Bucket" "aws s3api head-bucket --bucket ${PROJECT}-${ENV}-phi-data-\$(aws sts get-caller-identity --query Account --output text)"

echo ""
echo "── Azure DR (eastus) ────────────────────────────────────────────"
check "AKS Cluster" "az aks show --name ${PROJECT}-${ENV}-aks --resource-group ${PROJECT}-${ENV}-aks-rg --query 'provisioningState' --output tsv | grep -q Succeeded"
check "PostgreSQL" "az postgres flexible-server show --name ${PROJECT}-${ENV}-pg-dr --resource-group ${PROJECT}-${ENV}-databases-rg --query 'state' --output tsv | grep -q Ready"
check "Redis Cache" "az redis show --name ${PROJECT}-${ENV}-redis-dr --resource-group ${PROJECT}-${ENV}-databases-rg --query 'provisioningState' --output tsv | grep -q Succeeded"
check "Key Vault" "az keyvault show --name ${PROJECT}-${ENV}-kv --query 'properties.provisioningState' --output tsv | grep -q Succeeded"
check "Traffic Mgr" "az network traffic-manager profile show --name ${PROJECT}-${ENV}-tm --resource-group ${PROJECT}-${ENV}-monitoring-rg --query 'profileStatus' --output tsv | grep -q Enabled"

echo ""
echo "── Cross-Cloud ──────────────────────────────────────────────────"
check "VPN Connection" "az network vpn-connection show --name ${PROJECT}-${ENV}-aws-vpn-conn --resource-group ${PROJECT}-${ENV}-networking-rg --query 'connectionStatus' --output tsv | grep -q Connected"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✅ Healthy: $PASS  ❌ Unhealthy: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "  ⚠️  WARNING: Some services are unhealthy!"
    exit 1
else
    echo "  ✅ All services healthy."
    exit 0
fi
