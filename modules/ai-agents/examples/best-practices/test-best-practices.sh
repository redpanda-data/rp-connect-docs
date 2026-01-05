#!/usr/bin/env bash
#
# Automated testing script for Redpanda Connect Best Practices examples
#
# These examples are full pipelines (input/pipeline/output) that demonstrate
# best practices from the MCP documentation. Unlike MCP tool definitions,
# these can be executed directly with `rpk connect run`.
#
# Usage:
#   ./test-best-practices.sh                    # Test all examples
#   ./test-best-practices.sh input-validation   # Test specific category
#   ./test-best-practices.sh error-handling     # Test specific category

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL=0
PASSED=0
FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Redpanda Connect Best Practices Test Suite"
echo "=============================================="
echo ""

# Function to run a single test
run_test() {
    local file=$1
    local category=$(dirname "$file" | xargs basename)
    local name=$(basename "$file" .yaml)

    TOTAL=$((TOTAL + 1))

    echo -e "${BLUE}📄 Testing: $category/$name${NC}"

    # First, lint the configuration
    echo -n "  Linting... "
    if rpk connect lint --skip-env-var-check "$file" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo "    Lint errors:"
        rpk connect lint --skip-env-var-check "$file" 2>&1 | sed 's/^/    /'
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Run the example and capture output
    echo -n "  Running... "
    local output
    local exit_code=0

    # Run with timeout to prevent hanging
    output=$(timeout 30s rpk connect run "$file" 2>&1) || exit_code=$?

    # Check for success (exit code 0 means pipeline completed)
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}PASSED${NC}"
        PASSED=$((PASSED + 1))

        # Show sample output (first line only)
        local first_line=$(echo "$output" | grep -v "^time=" | head -1)
        if [[ -n "$first_line" ]]; then
            echo -e "    Output: ${first_line:0:80}..."
        fi
    elif [[ $exit_code -eq 124 ]]; then
        echo -e "${RED}FAILED${NC} (timeout after 30s)"
        FAILED=$((FAILED + 1))
        return 1
    else
        echo -e "${RED}FAILED${NC} (exit code: $exit_code)"
        echo "    Error output:"
        echo "$output" | grep -E "(error|Error|ERROR|failed|Failed)" | head -5 | sed 's/^/    /'
        FAILED=$((FAILED + 1))
        return 1
    fi

    return 0
}

# Determine which categories to test
if [[ $# -eq 0 ]]; then
    # Test all categories
    categories=("input-validation" "response-formatting" "error-handling")
else
    categories=("$@")
fi

# Run tests for each category
for category in "${categories[@]}"; do
    category_dir="$SCRIPT_DIR/$category"

    if [[ ! -d "$category_dir" ]]; then
        echo -e "${YELLOW}⚠️  Category not found: $category${NC}"
        continue
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📁 Category: ${BLUE}$category${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for file in "$category_dir"/*.yaml; do
        if [[ -f "$file" ]]; then
            run_test "$file" || true
            echo ""
        fi
    done
done

# Summary
echo ""
echo "=============================================="
echo "📊 Test Summary"
echo "=============================================="
echo "Total tests: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "Failed: ${RED}$FAILED${NC}"
fi
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
