#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Test Runner — OmniPresenseAI
# ─────────────────────────────────────────────────────────────
# Runs all test suites:
#   1. Chat Service unit tests (pytest)
#   2. Analytics Service unit tests (pytest)
#   3. Terraform/IaC compliance tests (pytest)
#   4. Project structure validation tests (pytest)
#
# Usage:
#   chmod +x scripts/run-tests.sh
#   ./scripts/run-tests.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_ERRORS=0

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  OmniPresenseAI — Full Test Suite"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─── Activate venv if exists ────────────────────────────────
if [ -f "$PROJECT_ROOT/.venv/bin/activate" ]; then
    source "$PROJECT_ROOT/.venv/bin/activate"
fi

mkdir -p "$PROJECT_ROOT/reports"

run_suite() {
    local name="$1"
    local dir="$2"
    local test_path="$3"
    local xml_name="$4"

    echo -e "${BLUE}━━━ $name ━━━${NC}"
    cd "$dir"

    if python -m pytest "$test_path" -v --tb=short --no-header \
        --junitxml="$PROJECT_ROOT/reports/${xml_name}.xml" 2>&1; then
        echo -e "${GREEN}  ✅ $name — PASSED${NC}"
    else
        echo -e "${RED}  ❌ $name — FAILURES${NC}"
    fi
    echo ""
}

# ─── 1. Chat Service Tests ──────────────────────────────────
run_suite "Chat Service Tests" "$PROJECT_ROOT/src/chat-service" "tests/" "chat-service"

# ─── 2. Analytics Service Tests ──────────────────────────────
run_suite "Analytics Service Tests" "$PROJECT_ROOT/src/analytics-service" "tests/" "analytics-service"

# ─── 3. Terraform/IaC Compliance Tests ──────────────────────
run_suite "Terraform Compliance Tests" "$PROJECT_ROOT" "tests/test_terraform_compliance.py" "terraform-compliance"

# ─── 4. Project Structure Tests ─────────────────────────────
run_suite "Project Structure Tests" "$PROJECT_ROOT" "tests/test_project_structure.py" "project-structure"

echo "═══════════════════════════════════════════════════════"
echo "  All Test Suites Complete"
echo "═══════════════════════════════════════════════════════"

# ─── Generate HTML Dashboard ────────────────────────────────
echo ""
echo -e "${YELLOW}📊 Generating test dashboard...${NC}"
cd "$PROJECT_ROOT"
python scripts/generate-test-dashboard.py

echo ""
echo -e "${GREEN}🌐 Open dashboard:${NC}"
echo "   open reports/dashboard.html"
echo ""

# Auto-open on macOS
if command -v open &>/dev/null; then
    open "$PROJECT_ROOT/reports/dashboard.html"
fi

