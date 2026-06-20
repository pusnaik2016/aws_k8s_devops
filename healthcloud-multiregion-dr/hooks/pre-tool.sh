#!/usr/bin/env bash
# ============================================================================
# pre-tool.sh — Dangerous Command Gatekeeper
# ============================================================================
# This hook intercepts potentially destructive commands and blocks execution
# until explicit human approval is given. All decisions are logged.
#
# Usage: Called automatically by Claude Code before executing terminal commands.
# Audit: All decisions logged to .claude/audit.log
# ============================================================================

set -euo pipefail

COMMAND="$*"
AUDIT_LOG=".claude/audit.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p .claude

# ──────────────────────────────────────────────────────────────────────────────
# Dangerous command patterns (case-insensitive matching)
# ──────────────────────────────────────────────────────────────────────────────

DANGEROUS_PATTERNS=(
    # Terraform
    "terraform apply"
    "terraform destroy"
    "terraform import"
    "terraform state rm"
    "terraform state mv"
    "terraform taint"
    "terraform untaint"

    # Kubernetes
    "kubectl delete namespace"
    "kubectl delete deployment"
    "kubectl delete statefulset"
    "kubectl delete -f"
    "kubectl delete --all"
    "kubectl drain"
    "kubectl cordon"

    # AWS
    "aws iam delete"
    "aws s3 rb"
    "aws s3 rm.*--recursive"
    "aws ec2 terminate-instances"
    "aws rds delete-db-instance"
    "aws rds delete-db-cluster"
    "aws eks delete-cluster"
    "aws kms schedule-key-deletion"
    "aws secretsmanager delete"

    # Azure
    "az group delete"
    "az aks delete"
    "az postgres.*delete"
    "az keyvault delete"
    "az storage account delete"
    "az network vnet delete"

    # System
    "rm -rf"
    "rm -r /"
    "git push --force"
    "git push -f"
    "git reset --hard"

    # Docker
    "docker system prune"
    "docker volume prune"
    "docker container prune"

    # Helm
    "helm uninstall"
    "helm delete"
)

# ──────────────────────────────────────────────────────────────────────────────
# Check if command matches any dangerous pattern
# ──────────────────────────────────────────────────────────────────────────────

MATCHED_PATTERN=""
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        MATCHED_PATTERN="$pattern"
        break
    fi
done

if [[ -n "$MATCHED_PATTERN" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  🛑 DANGEROUS COMMAND DETECTED                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Command:  $COMMAND"
    echo "  Pattern:  $MATCHED_PATTERN"
    echo "  Time:     $TIMESTAMP"
    echo ""
    echo "  This command can cause irreversible changes to infrastructure."
    echo "  In a HIPAA-compliant healthcare environment, unauthorized changes"
    echo "  may result in compliance violations."
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    read -p "  Type 'yes' to proceed, anything else to abort: " CONFIRM

    if [[ "$CONFIRM" == "yes" ]]; then
        echo "[$TIMESTAMP] APPROVED: $COMMAND (pattern: $MATCHED_PATTERN)" >> "$AUDIT_LOG"
        echo ""
        echo "  ✅ Approved — executing command..."
        echo ""
        exit 0
    else
        echo "[$TIMESTAMP] BLOCKED: $COMMAND (pattern: $MATCHED_PATTERN)" >> "$AUDIT_LOG"
        echo ""
        echo "  ❌ Blocked — command was NOT executed."
        echo ""
        exit 1
    fi
else
    # Command is safe — allow execution silently
    exit 0
fi
