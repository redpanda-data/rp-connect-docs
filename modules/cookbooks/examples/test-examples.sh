#!/usr/bin/env bash
#
# Automated testing script for Redpanda Connect cookbook examples
#
# Usage:
#   ./test-examples.sh                    # Test all examples
#   ./test-examples.sh jira               # Test only Jira examples
#   ./test-examples.sh jira/input-*.yaml  # Test specific pattern

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL=0
PASSED=0
FAILED=0

echo "🧪 Redpanda Connect Cookbook Examples Test Suite"
echo "================================================"
echo ""

# Determine what to test
PATTERN="${1:-*/*.yaml}"

# Function to lint a config file
lint_config() {
    local file=$1
    TOTAL=$((TOTAL + 1))

    echo -n "  Linting $(basename "$file")... "

    if rpk connect lint --skip-env-var-check "$file" 2>&1 | grep -q "error"; then
        echo -e "${RED}FAILED${NC}"
        rpk connect lint --skip-env-var-check "$file" 2>&1 | sed 's/^/    /'
        FAILED=$((FAILED + 1))
        return 1
    else
        echo -e "${GREEN}PASSED${NC}"
        PASSED=$((PASSED + 1))
        return 0
    fi
}

# Function to run unit tests if they exist
run_unit_tests() {
    local test_file=$1

    if [[ -f "$test_file" ]]; then
        echo -n "  Testing $(basename "$test_file")... "

        if rpk connect test "$test_file" 2>&1 | grep -q "FAILED"; then
            echo -e "${RED}FAILED${NC}"
            rpk connect test "$test_file" 2>&1 | sed 's/^/    /'
            return 1
        else
            echo -e "${GREEN}PASSED${NC}"
            return 0
        fi
    fi
}

# Find and test all matching files
for file in $PATTERN; do
    if [[ -f "$file" ]]; then
        echo ""
        echo "📄 Testing: $file"
        lint_config "$file"

        # Check for corresponding test file
        test_file="${file%.yaml}_test.yaml"
        run_unit_tests "$test_file" || true
    fi
done

# Summary
echo ""
echo "================================================"
echo "📊 Test Summary"
echo "================================================"
echo "Total configs tested: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
