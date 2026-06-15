#!/usr/bin/env bash
# =============================================================================
# health-check.sh — Full System Health Check
# =============================================================================
# Usage:
#   bash scripts/health-check.sh staging
#   bash scripts/health-check.sh production
# =============================================================================
set -euo pipefail

ENV=${1:-staging}
INVENTORY="inventories/${ENV}/hosts.ini"
VAULT="--vault-password-file .vault-pass"
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
  local label=$1
  local cmd=$2
  printf "  %-40s" "${label}..."
  if eval "${cmd}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
    ((PASS++))
  else
    echo -e "${RED}❌ FAIL${NC}"
    ((FAIL++))
  fi
}

echo ""
echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   Ansible Config Mgmt — Health Check [${ENV}]${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
echo ""

# --- Connectivity ---
echo "📡 Connectivity"
check "Ping all hosts" \
  "ansible all -i ${INVENTORY} -m ping ${VAULT}"
check "Ping web tier" \
  "ansible web -i ${INVENTORY} -m ping ${VAULT}"
check "Ping app tier" \
  "ansible app -i ${INVENTORY} -m ping ${VAULT}"
check "Ping db tier" \
  "ansible db -i ${INVENTORY} -m ping ${VAULT}"

echo ""

# --- Service Status ---
echo "⚙️  Service Status"
check "NGINX active (web)" \
  "ansible web -i ${INVENTORY} -m command -a 'systemctl is-active nginx' ${VAULT}"
check "MyApp active (app)" \
  "ansible app -i ${INVENTORY} -m command -a 'systemctl is-active myapp' ${VAULT}"
check "PostgreSQL active (db)" \
  "ansible db -i ${INVENTORY} -m command -a 'systemctl is-active postgresql' ${VAULT}"
check "fail2ban active (all)" \
  "ansible all -i ${INVENTORY} -m command -a 'systemctl is-active fail2ban' ${VAULT}"
check "UFW enabled (all)" \
  "ansible all -i ${INVENTORY} -m command -a 'ufw status | grep -q active' ${VAULT}"

echo ""

# --- Application Health ---
echo "🏥 Application Health"
check "App /health endpoint" \
  "ansible app -i ${INVENTORY} -m uri -a 'url=http://localhost:8080/health method=GET status_code=200' ${VAULT}"
check "NGINX /nginx-health" \
  "ansible web -i ${INVENTORY} -m uri -a 'url=http://localhost/nginx-health method=GET status_code=200' ${VAULT}"

echo ""

# --- Disk Space (warn if >80%) ---
echo "💾 Disk Space"
check "Disk usage <80% (all hosts)" \
  "ansible all -i ${INVENTORY} -m command -a \"bash -c 'df / | awk \\\"NR==2{if(\\\$5+0>80) exit 1}\\\"'\" ${VAULT}"

echo ""

# --- Summary ---
echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ "${FAIL}" -eq 0 ]; then
  echo -e "  ${GREEN}✅ All ${TOTAL} checks passed${NC}"
else
  echo -e "  ${RED}❌ ${FAIL}/${TOTAL} checks FAILED${NC}"
fi
echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
echo ""

exit ${FAIL}
