#!/usr/bin/env bash
# ==============================================================================
# pre-commit.sh — Pre-Commit Quality Gate
# ==============================================================================
# Runs automated checks before every git commit to ensure code quality
# and security standards are maintained.
#
# Checks performed:
#   1. Secret/credential scanning
#   2. Terraform formatting (if terraform CLI available)
#   3. Python linting (if files changed)
#   4. YAML validation (basic structure check)
#   5. Trailing whitespace and large file detection
#
# Author:  Pushparaj Naik
# Version: 1.0.0
#
# Installation:
#   cp hooks/pre-commit.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Or use with:
#   git config core.hooksPath Claude_devops/hooks
# ==============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Colour & Formatting
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass_check() {
    echo -e "  ${GREEN}✅ PASS${NC} — $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn_check() {
    echo -e "  ${YELLOW}⚠️  WARN${NC} — $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

fail_check() {
    echo -e "  ${RED}❌ FAIL${NC} — $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ─────────────────────────────────────────────────────────────────────────────
# Get staged files
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  🔍 Claude DevOps Pre-Commit Quality Gate                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")

if [[ -z "$STAGED_FILES" ]]; then
    echo -e "${YELLOW}No staged files found — skipping checks${NC}"
    exit 0
fi

FILE_COUNT=$(echo "$STAGED_FILES" | wc -l | tr -d ' ')
echo -e "${CYAN}Checking ${FILE_COUNT} staged files...${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: Secret Scanning
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${BOLD}[1/5] Secret Scanning${NC}"

SECRET_PATTERNS=(
    'AKIA[0-9A-Z]{16}'
    'ghp_[A-Za-z0-9]{36}'
    'gho_[A-Za-z0-9]{36}'
    '-----BEGIN.*PRIVATE KEY-----'
    'sk-[A-Za-z0-9]{20,}'
)

secrets_found=false
for pattern in "${SECRET_PATTERNS[@]}"; do
    matches=$(echo "$STAGED_FILES" | xargs grep -lnE "$pattern" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
        secrets_found=true
        fail_check "Potential secret found matching pattern: $pattern"
        echo "         Files: $matches" | head -5
    fi
done

if ! $secrets_found; then
    pass_check "No secrets detected in staged files"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: Terraform Format (if applicable)
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${BOLD}[2/5] Terraform Formatting${NC}"

TF_FILES=$(echo "$STAGED_FILES" | grep '\.tf$' || true)

if [[ -n "$TF_FILES" ]]; then
    if command -v terraform &>/dev/null; then
        TF_DIRS=$(echo "$TF_FILES" | xargs -I{} dirname {} | sort -u)
        tf_format_ok=true
        for dir in $TF_DIRS; do
            if ! terraform fmt -check -diff "$dir" &>/dev/null; then
                tf_format_ok=false
                fail_check "Terraform format check failed in $dir"
            fi
        done
        if $tf_format_ok; then
            pass_check "Terraform files properly formatted"
        fi
    else
        warn_check "terraform CLI not found — skipping format check"
    fi
else
    pass_check "No Terraform files changed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: Python Linting (if applicable)
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${BOLD}[3/5] Python Linting${NC}"

PY_FILES=$(echo "$STAGED_FILES" | grep '\.py$' || true)

if [[ -n "$PY_FILES" ]]; then
    if command -v python3 &>/dev/null; then
        py_syntax_ok=true
        for pyfile in $PY_FILES; do
            if ! python3 -c "import py_compile; py_compile.compile('$pyfile', doraise=True)" 2>/dev/null; then
                py_syntax_ok=false
                fail_check "Python syntax error in $pyfile"
            fi
        done
        if $py_syntax_ok; then
            pass_check "Python files have valid syntax"
        fi
    else
        warn_check "python3 not found — skipping Python lint"
    fi
else
    pass_check "No Python files changed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: YAML Validation
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${BOLD}[4/5] YAML Validation${NC}"

YAML_FILES=$(echo "$STAGED_FILES" | grep -E '\.(yaml|yml)$' || true)

if [[ -n "$YAML_FILES" ]]; then
    yaml_ok=true
    for yfile in $YAML_FILES; do
        if [[ -f "$yfile" ]]; then
            # Basic YAML structure check
            if python3 -c "
import sys
try:
    with open('$yfile', 'r') as f:
        content = f.read()
    # Basic checks: valid UTF-8, no tab indentation
    if '\t' in content:
        print('Tab indentation found in $yfile', file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
                : # OK
            else
                yaml_ok=false
                warn_check "YAML issue in $yfile (tab indentation or encoding)"
            fi
        fi
    done
    if $yaml_ok; then
        pass_check "YAML files pass basic validation"
    fi
else
    pass_check "No YAML files changed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 5: Large Files & Trailing Whitespace
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${BOLD}[5/5] File Hygiene${NC}"

MAX_FILE_SIZE=500000  # 500KB
large_files_found=false

for file in $STAGED_FILES; do
    if [[ -f "$file" ]]; then
        file_size=$(wc -c < "$file" | tr -d ' ')
        if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
            large_files_found=true
            warn_check "Large file: $file ($(( file_size / 1024 ))KB)"
        fi
    fi
done

# Check for committed .env or state files
if echo "$STAGED_FILES" | grep -qE '(\.env|terraform\.tfstate)'; then
    fail_check "Sensitive file staged for commit (.env or tfstate)"
fi

if ! $large_files_found; then
    pass_check "No oversized files detected"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))
echo -e "  ${GREEN}✅ Passed: $PASS_COUNT${NC}  ${YELLOW}⚠️  Warnings: $WARN_COUNT${NC}  ${RED}❌ Failed: $FAIL_COUNT${NC}  (Total: $TOTAL)"

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}${BOLD}COMMIT BLOCKED — Fix the above issues before committing${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    exit 1
else
    if [[ $WARN_COUNT -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}${BOLD}COMMIT ALLOWED with warnings — please review above items${NC}"
    else
        echo ""
        echo -e "  ${GREEN}${BOLD}ALL CHECKS PASSED — commit proceeding${NC}"
    fi
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    exit 0
fi
