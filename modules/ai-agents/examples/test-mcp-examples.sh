#!/usr/bin/env bash
#
# Automated testing script for Redpanda Connect MCP examples
#
# Usage:
#   ./test-mcp-examples.sh                      # Test all examples
#   ./test-mcp-examples.sh processors           # Test only processor examples
#   ./test-mcp-examples.sh resources/processors/*.yaml  # Test specific pattern

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
SKIPPED=0

echo "🧪 Redpanda Connect MCP Examples Test Suite"
echo "============================================"
echo ""

# Determine what to test
PATTERN="${1:-}"

if [[ -z "$PATTERN" ]]; then
    # Default: test all resource examples
    PATTERN="resources/*/*.yaml o11y/*.yaml"
elif [[ "$PATTERN" == "processors" ]] || [[ "$PATTERN" == "inputs" ]] || [[ "$PATTERN" == "outputs" ]] || [[ "$PATTERN" == "caches" ]]; then
    # Test specific component type
    PATTERN="resources/${PATTERN}/*.yaml"
elif [[ "$PATTERN" == "o11y" ]]; then
    # Test observability configs
    PATTERN="o11y/*.yaml"
fi

# Function to lint a config file
lint_config() {
    local file=$1
    local component_type=$2
    TOTAL=$((TOTAL + 1))

    echo -n "  Linting $(basename "$file")... "

    # Skip environment variable checks for MCP examples as they may use ${secrets.X} or ${X}
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

# Function to validate MCP metadata
validate_mcp_metadata() {
    local file=$1
    local component_type=$2

    echo -n "  Validating MCP metadata... "

    # Check if file has MCP metadata
    if ! grep -q "meta:" "$file" || ! grep -q "mcp:" "$file"; then
        echo -e "${YELLOW}SKIPPED${NC} (no MCP metadata)"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    # Check for required MCP fields
    local has_enabled=$(grep -c "enabled: true" "$file" || echo 0)
    local has_description=$(grep -c "description:" "$file" || echo 0)

    if [[ $has_enabled -eq 0 ]]; then
        echo -e "${YELLOW}WARNING${NC} (mcp.enabled not set to true)"
        return 0
    fi

    if [[ $has_description -eq 0 ]]; then
        echo -e "${RED}FAILED${NC} (missing description)"
        return 1
    fi

    echo -e "${GREEN}PASSED${NC}"
    return 0
}


# Function to determine component type from path
get_component_type() {
    local file=$1
    if [[ "$file" =~ resources/inputs/ ]]; then
        echo "input"
    elif [[ "$file" =~ resources/outputs/ ]]; then
        echo "output"
    elif [[ "$file" =~ resources/processors/ ]]; then
        echo "processor"
    elif [[ "$file" =~ resources/caches/ ]]; then
        echo "cache"
    elif [[ "$file" =~ o11y/ ]]; then
        echo "o11y"
    else
        echo "unknown"
    fi
}

# Find and test all matching files
for file in $PATTERN; do
    if [[ -f "$file" ]]; then
        component_type=$(get_component_type "$file")

        echo ""
        echo -e "${BLUE}📄 Testing: $file${NC} (${component_type})"

        # Lint the config
        if lint_config "$file" "$component_type"; then
            # Validate MCP metadata (if applicable)
            if [[ "$component_type" != "o11y" ]]; then
                validate_mcp_metadata "$file" "$component_type" || true
            fi
        fi
    fi
done

# Summary
echo ""
echo "============================================"
echo "📊 Test Summary"
echo "============================================"
echo "Total configs tested: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
if [[ $SKIPPED -gt 0 ]]; then
    echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
fi
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
