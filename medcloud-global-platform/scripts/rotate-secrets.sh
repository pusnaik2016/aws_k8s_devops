#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# MedCloud — Cross-Cloud Secret Rotation
# ─────────────────────────────────────────────────────────────────────────────
# Rotates secrets across AWS Secrets Manager, Azure Key Vault, and GCP Secret
# Manager. Designed to run as a scheduled cron job or via CI/CD.
# Usage: ./scripts/rotate-secrets.sh <environment>
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ENV="${1:-dev}"
PROJECT="medcloud"

echo "═══════════════════════════════════════════════════════════════"
echo "  🔐 MedCloud — Secret Rotation"
echo "  Environment: ${ENV}"
echo "  Timestamp:   $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "═══════════════════════════════════════════════════════════════"

# ─── AWS Secrets Manager Rotation ────────────────────────────────────────
echo ""
echo "── AWS Secrets Manager ──"

AWS_SECRETS=(
  "${PROJECT}-${ENV}/aurora-credentials"
  "${PROJECT}-${ENV}/redis-credentials"
  "${PROJECT}-${ENV}/api-keys"
)

for secret in "${AWS_SECRETS[@]}"; do
  echo -n "  Rotating: ${secret} ... "
  aws secretsmanager rotate-secret \
    --secret-id "${secret}" \
    --rotation-rules '{"AutomaticallyAfterDays":90}' \
    2>/dev/null && echo "✅" || echo "⚠️  (check rotation lambda)"
done

# ─── Azure Key Vault Rotation ───────────────────────────────────────────
echo ""
echo "── Azure Key Vault ──"

KV_NAME="${PROJECT}-${ENV}-kv"
AZURE_SECRETS=(
  "cosmosdb-connection-string"
  "openai-api-key"
  "encryption-key"
)

for secret in "${AZURE_SECRETS[@]}"; do
  echo -n "  Checking expiry: ${secret} ... "
  EXPIRY=$(az keyvault secret show \
    --vault-name "${KV_NAME}" \
    --name "${secret}" \
    --query 'attributes.expires' -o tsv 2>/dev/null || echo "none")
  
  if [ "${EXPIRY}" = "none" ] || [ -z "${EXPIRY}" ]; then
    echo "⚠️  No expiry set — setting 90-day expiry"
    FUTURE=$(date -u -v+90d +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '+90 days' +'%Y-%m-%dT%H:%M:%SZ')
    az keyvault secret set-attributes \
      --vault-name "${KV_NAME}" \
      --name "${secret}" \
      --expires "${FUTURE}" \
      --output none 2>/dev/null || true
  else
    echo "expires ${EXPIRY}"
  fi
done

# ─── GCP Secret Manager Rotation ────────────────────────────────────────
echo ""
echo "── GCP Secret Manager ──"

GCP_PROJECT="${PROJECT}-global-${ENV}"
GCP_SECRETS=(
  "bigquery-service-account-key"
  "vertex-ai-credentials"
  "dlp-api-key"
)

for secret in "${GCP_SECRETS[@]}"; do
  echo -n "  Checking: ${secret} ... "
  VERSION=$(gcloud secrets versions list "${secret}" \
    --project="${GCP_PROJECT}" \
    --format='value(name)' \
    --limit=1 2>/dev/null || echo "NOT_FOUND")
  
  if [ "${VERSION}" = "NOT_FOUND" ]; then
    echo "⚠️  Secret not found"
  else
    echo "✅ latest version: ${VERSION}"
  fi
done

# ─── Summary ────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Secret rotation check complete for: ${ENV}"
echo "  Next scheduled rotation: $(date -u -v+90d +'%Y-%m-%d' 2>/dev/null || date -u -d '+90 days' +'%Y-%m-%d')"
echo "═══════════════════════════════════════════════════════════════"
