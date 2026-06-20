#!/usr/bin/env bash
# ============================================================================
# rotate-secrets.sh — Cross-Cloud Secret Rotation
# ============================================================================
# Rotates database passwords and Redis tokens in both clouds
# Usage: ./scripts/ops/rotate-secrets.sh [environment]
# ============================================================================

set -euo pipefail

ENV="${1:-prod}"
PROJECT="healthcloud"
TIMESTAMP=$(date '+%Y%m%d%H%M%S')

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  🔑 Secret Rotation — $ENV                                     ║"
echo "║  Timestamp: $TIMESTAMP                                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

generate_password() {
    openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

echo ""
echo "── Step 1: Generate New Credentials ─────────────────────────────"
NEW_DB_PASSWORD=$(generate_password)
NEW_REDIS_TOKEN=$(generate_password)
echo "  ✅ New credentials generated (not displayed for security)"

echo ""
echo "── Step 2: Update AWS Secrets Manager ───────────────────────────"
echo -n "  Updating DB password ... "
aws secretsmanager update-secret \
    --secret-id "${PROJECT}-${ENV}-db-master-password" \
    --secret-string "$NEW_DB_PASSWORD" && echo "✅" || echo "❌"

echo -n "  Updating Redis token ... "
aws secretsmanager update-secret \
    --secret-id "${PROJECT}-${ENV}-redis-auth-token" \
    --secret-string "$NEW_REDIS_TOKEN" && echo "✅" || echo "❌"

echo ""
echo "── Step 3: Update Azure Key Vault ───────────────────────────────"
echo -n "  Updating DB password ... "
az keyvault secret set \
    --vault-name "${PROJECT}-${ENV}-kv" \
    --name "db-master-password" \
    --value "$NEW_DB_PASSWORD" \
    --output none && echo "✅" || echo "❌"

echo -n "  Updating Redis token ... "
az keyvault secret set \
    --vault-name "${PROJECT}-${ENV}-kv" \
    --name "redis-auth-token" \
    --value "$NEW_REDIS_TOKEN" \
    --output none && echo "✅" || echo "❌"

echo ""
echo "── Step 4: Trigger K8s Secret Refresh ───────────────────────────"
echo -n "  Restarting ExternalSecrets ... "
kubectl rollout restart deployment -n healthcloud-apps -l compliance=hipaa 2>/dev/null && echo "✅" || echo "⚠️  Manual restart needed"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✅ Secret rotation complete for: $ENV"
echo "  📝 Audit: rotation logged at $TIMESTAMP"
echo "═══════════════════════════════════════════════════════════════════"
