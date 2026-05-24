#!/usr/bin/env bash
# ==============================================================================
# pre-tool.sh — Dangerous Command Gatekeeper
# ==============================================================================
# This hook intercepts potentially destructive CLI commands and requires
# explicit manual approval before allowing execution.
#
# Design: Intended to be wired into Claude Code's PreToolUse hook system.
# When Claude attempts to execute a terminal command, this script checks
# whether the command matches any dangerous pattern and blocks it if so.
#
# Author:  Pushparaj Naik
# Version: 1.0.0
#
# Usage:
#   ./hooks/pre-tool.sh "<command_string>"
#
# Exit codes:
#   0 = Command is safe, proceed
#   1 = Command is dangerous and was NOT approved
#   2 = Command is dangerous and WAS approved
# ==============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration: Dangerous command patterns
# ─────────────────────────────────────────────────────────────────────────────

DANGEROUS_PATTERNS=(
    "terraform apply"
    "terraform destroy"
    "terraform import"
    "terraform taint"
    "terraform untaint"
    "terraform state rm"
    "terraform state mv"
    "kubectl delete namespace"
    "kubectl delete deployment"
    "kubectl delete statefulset"
    "kubectl delete daemonset"
    "kubectl delete -f"
    "kubectl delete --all"
    "kubectl exec"
    "kubectl drain"
    "kubectl cordon"
    "aws iam delete"
    "aws s3 rb"
    "aws s3 rm --recursive"
    "aws ec2 terminate-instances"
    "aws rds delete"
    "aws eks delete"
    "aws cloudformation delete"
    "rm -rf"
    "rm -r /"
    "docker system prune"
    "docker volume prune"
    "helm uninstall"
    "helm delete"
    "git push --force"
    "git push -f"
    "git reset --hard"
)

# Informational patterns (warn but don't block)
WARN_PATTERNS=(
    "terraform plan"
    "kubectl apply"
    "kubectl scale"
    "kubectl rollout"
    "helm upgrade"
    "helm install"
    "docker build"
    "docker push"
    "git push"
)

# ─────────────────────────────────────────────────────────────────────────────
# Colour & Formatting
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ─────────────────────────────────────────────────────────────────────────────
# Main Logic
# ─────────────────────────────────────────────────────────────────────────────

COMMAND="${1:-}"

if [[ -z "$COMMAND" ]]; then
    echo -e "${RED}Error: No command provided${NC}"
    echo "Usage: $0 \"<command_string>\""
    exit 1
fi

# Check against dangerous patterns
is_dangerous=false
matched_pattern=""

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qi "$pattern"; then
        is_dangerous=true
        matched_pattern="$pattern"
        break
    fi
done

if $is_dangerous; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⛔  DANGEROUS COMMAND DETECTED                                 ║${NC}"
    echo -e "${RED}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC}                                                                ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${BOLD}Command:${NC}  $COMMAND"
    echo -e "${RED}║${NC}  ${BOLD}Pattern:${NC}  $matched_pattern"
    echo -e "${RED}║${NC}                                                                ${RED}║${NC}"
    echo -e "${RED}║${NC}  This command has been flagged as potentially destructive.     ${RED}║${NC}"
    echo -e "${RED}║${NC}  It may cause irreversible changes to your infrastructure.     ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                                ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # In interactive mode, ask for confirmation
    if [[ -t 0 ]]; then
        echo -e "${YELLOW}Do you want to proceed? (type 'yes' to confirm)${NC}"
        read -r confirmation
        if [[ "$confirmation" == "yes" ]]; then
            echo -e "${GREEN}✅ Command approved by user${NC}"
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] APPROVED: $COMMAND" >> "${0%/*}/../.claude/audit.log" 2>/dev/null || true
            exit 2
        else
            echo -e "${RED}❌ Command blocked${NC}"
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] BLOCKED: $COMMAND" >> "${0%/*}/../.claude/audit.log" 2>/dev/null || true
            exit 1
        fi
    else
        # Non-interactive: block by default
        echo -e "${RED}❌ Command blocked (non-interactive mode — manual approval required)${NC}"
        exit 1
    fi
fi

# Check against warning patterns
for pattern in "${WARN_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qi "$pattern"; then
        echo -e "${YELLOW}⚠️  Heads up: '${pattern}' detected in command${NC}"
        echo -e "${CYAN}   Command: $COMMAND${NC}"
        echo -e "${GREEN}   Proceeding...${NC}"
        break
    fi
done

# Command is safe
exit 0
