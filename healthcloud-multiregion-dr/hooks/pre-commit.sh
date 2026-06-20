#!/usr/bin/env bash
# ============================================================================
# pre-commit.sh — Pre-Commit Quality Gate
# ============================================================================
# Runs 6 automated checks before every git commit for HIPAA-compliant
# healthcare infrastructure. Blocks commits with critical findings.
#
# Install: cp hooks/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
# ============================================================================

set -euo pipefail

PASS=0
WARN=0
FAIL=0
TOTAL=6

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  🔍 HealthCloud Pre-Commit Quality Gate                         ║"
echo "║  HIPAA-Compliant Healthcare Platform                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Check 1: Secret Scanning
# ──────────────────────────────────────────────────────────────────────────────
echo -n "[1/$TOTAL] Secret Scanning ................. "

SECRETS_FOUND=0
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || echo "")

if [[ -n "$STAGED_FILES" ]]; then
    SECRET_PATTERNS=(
        'AKIA[0-9A-Z]{16}'                    # AWS Access Key
        'aws_secret_access_key\s*='            # AWS Secret Key
        'password\s*=\s*"[^"]{8,}"'            # Hardcoded password
        'BEGIN (RSA |DSA |EC )?PRIVATE KEY'     # Private keys
        'ghp_[0-9a-zA-Z]{36}'                  # GitHub PAT
        'sk-[0-9a-zA-Z]{48}'                   # OpenAI API key
        'DefaultEndpointsProtocol=https'        # Azure connection string
    )

    for file in $STAGED_FILES; do
        if [[ -f "$file" ]] && [[ ! "$file" =~ \.(png|jpg|jpeg|gif|ico|woff|ttf|zip|jar|pyc)$ ]]; then
            for pattern in "${SECRET_PATTERNS[@]}"; do
                if grep -qE "$pattern" "$file" 2>/dev/null; then
                    SECRETS_FOUND=1
                    echo ""
                    echo "    ❌ Secret pattern found in: $file"
                fi
            done
        fi
    done
fi

if [[ $SECRETS_FOUND -eq 0 ]]; then
    echo "✅ PASS"
    ((PASS++))
else
    echo "❌ FAIL"
    ((FAIL++))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 2: Terraform Formatting
# ──────────────────────────────────────────────────────────────────────────────
echo -n "[2/$TOTAL] Terraform Formatting ............ "

TF_FILES=$(echo "$STAGED_FILES" | grep '\.tf$' || echo "")
if [[ -n "$TF_FILES" ]]; then
    if command -v terraform &>/dev/null; then
        TF_FMT=$(terraform fmt -check -recursive ./terraform 2>/dev/null || echo "FAIL")
        if [[ "$TF_FMT" == "FAIL" ]] || [[ -n "$TF_FMT" ]]; then
            echo "⚠️  WARN — Run: terraform fmt -recursive ./terraform"
            ((WARN++))
        else
            echo "✅ PASS"
            ((PASS++))
        fi
    else
        echo "⏭️  SKIP (terraform CLI not installed)"
        ((PASS++))
    fi
else
    echo "⏭️  SKIP (no .tf files staged)"
    ((PASS++))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 3: Python Linting
# ──────────────────────────────────────────────────────────────────────────────
echo -n "[3/$TOTAL] Python Linting .................. "

PY_FILES=$(echo "$STAGED_FILES" | grep '\.py$' || echo "")
if [[ -n "$PY_FILES" ]]; then
    PY_ERRORS=0
    for pyfile in $PY_FILES; do
        if [[ -f "$pyfile" ]]; then
            python3 -c "
import py_compile, sys
try:
    py_compile.compile('$pyfile', doraise=True)
except py_compile.PyCompileError as e:
    print(f'    Syntax error: {e}')
    sys.exit(1)
" 2>/dev/null || PY_ERRORS=1
        fi
    done
    if [[ $PY_ERRORS -eq 0 ]]; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "❌ FAIL"
        ((FAIL++))
    fi
else
    echo "⏭️  SKIP (no .py files staged)"
    ((PASS++))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 4: YAML Validation
# ──────────────────────────────────────────────────────────────────────────────
echo -n "[4/$TOTAL] YAML Validation ................. "

YAML_FILES=$(echo "$STAGED_FILES" | grep -E '\.(yaml|yml)$' || echo "")
if [[ -n "$YAML_FILES" ]]; then
    YAML_ERRORS=0
    for yfile in $YAML_FILES; do
        if [[ -f "$yfile" ]]; then
            python3 -c "
import yaml, sys
try:
    with open('$yfile') as f:
        list(yaml.safe_load_all(f))
except Exception as e:
    print(f'    YAML error in $yfile: {e}')
    sys.exit(1)
" 2>/dev/null || YAML_ERRORS=1
        fi
    done
    if [[ $YAML_ERRORS -eq 0 ]]; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "⚠️  WARN — YAML syntax issues found"
        ((WARN++))
    fi
else
    echo "⏭️  SKIP (no YAML files staged)"
    ((PASS++))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 5: Docker Image Tag Pinning
# ──────────────────────────────────────────────────────────────────────────────
echo -n "[5/$TOTAL] Docker Image Pinning ............ "

DOCKER_FILES=$(echo "$STAGED_FILES" | grep -i 'Dockerfile' || echo "")
if [[ -n "$DOCKER_FILES" ]]; then
    LATEST_FOUND=0
    for dfile in $DOCKER_FILES; do
        if [[ -f "$dfile" ]]; then
            if grep -qE '^FROM.*:latest' "$dfile" 2>/dev/null; then
                echo ""
                echo "    ❌ :latest tag found in: $dfile"
                LATEST_FOUND=1
            fi
        fi
    done
    if [[ $LATEST_FOUND -eq 0 ]]; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "❌ FAIL"
        ((FAIL++))
    fi
else
    echo "⏭️  SKIP (no Dockerfiles staged)"
    ((PASS++))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Check 6: PHI Exposure Check (HIPAA)
# ──────────────────────────────────────────────────────────────────────────────
echo -n "[6/$TOTAL] PHI Exposure Check .............. "

PHI_FOUND=0
PHI_PATTERNS=(
    'patient_name\s*='
    'social_security\s*='
    'ssn\s*='
    'date_of_birth\s*='
    'medical_record\s*='
    'diagnosis\s*='
    'health_insurance\s*='
)

for file in $STAGED_FILES; do
    if [[ -f "$file" ]] && [[ "$file" =~ \.(py|java|tf|yaml|yml|json|md)$ ]]; then
        for pattern in "${PHI_PATTERNS[@]}"; do
            if grep -qiE "$pattern" "$file" 2>/dev/null; then
                # Exclude docs and variable declarations
                if [[ ! "$file" =~ (docs/|README|ARCHITECTURE|variables\.tf) ]]; then
                    echo ""
                    echo "    ⚠️  Potential PHI in: $file (pattern: $pattern)"
                    PHI_FOUND=1
                fi
            fi
        done
    fi
done

if [[ $PHI_FOUND -eq 0 ]]; then
    echo "✅ PASS"
    ((PASS++))
else
    echo "⚠️  WARN — Review PHI handling"
    ((WARN++))
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✅ Passed: $PASS  ⚠️  Warnings: $WARN  ❌ Failed: $FAIL  (Total: $TOTAL)"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "  ❌ COMMIT BLOCKED — Fix critical issues above before committing."
    echo "═══════════════════════════════════════════════════════════════════"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo "  ⚠️  COMMIT ALLOWED with warnings — please review above items."
    echo "═══════════════════════════════════════════════════════════════════"
    exit 0
else
    echo "  ✅ All checks passed — commit allowed."
    echo "═══════════════════════════════════════════════════════════════════"
    exit 0
fi
