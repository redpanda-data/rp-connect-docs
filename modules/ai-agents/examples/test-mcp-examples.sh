#!/usr/bin/env bash
#
# Automated testing script for Redpanda Connect MCP examples
#
# Usage:
#   ./test-mcp-examples.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL=0
SKIPPED=0
MCP_FAILS=0

echo "🧪 Redpanda Connect MCP Examples Test Suite"
echo "============================================"
echo ""

# Run MCP server lint on the directory
echo "Running rpk connect mcp-server lint..."
LINT_OUTPUT=$(rpk connect mcp-server lint --skip-env-var-check --verbose 2>&1) || {
    echo -e "${RED}❌ Linting failed${NC}"
    echo ""
    echo "$LINT_OUTPUT"
    exit 1
}
echo -e "${GREEN}✅ Linting passed${NC}"
echo ""

# Function to validate MCP metadata
validate_mcp_metadata() {
    local file=$1

    echo -n "  Validating MCP metadata... "

    # Determine which YAML parser to use
    local use_yq=true
    if ! command -v yq &> /dev/null; then
        use_yq=false
        if ! command -v python3 &> /dev/null; then
            echo -e "${RED}FAILED${NC} (neither yq nor python3 available)"
            MCP_FAILS=$((MCP_FAILS + 1))
            return 1
        fi
    fi

    # Check if .meta.mcp exists
    local mcp_exists
    if $use_yq; then
        mcp_exists=$(yq eval '.meta.mcp' "$file" 2>/dev/null)
    else
        mcp_exists=$(python3 -c "
import yaml
try:
    with open('$file') as f:
        doc = yaml.safe_load(f)
    meta = doc.get('meta', {}) if doc else {}
    mcp = meta.get('mcp')
    print('null' if mcp is None else 'exists')
except:
    print('null')
" 2>/dev/null)
    fi

    if [[ "$mcp_exists" == "null" || -z "$mcp_exists" ]]; then
        echo -e "${YELLOW}SKIPPED${NC} (no MCP metadata)"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    # Read .meta.mcp.enabled
    local enabled
    if $use_yq; then
        enabled=$(yq eval '.meta.mcp.enabled' "$file" 2>/dev/null)
    else
        enabled=$(python3 -c "
import yaml
try:
    with open('$file') as f:
        doc = yaml.safe_load(f)
    enabled = doc.get('meta', {}).get('mcp', {}).get('enabled')
    print('null' if enabled is None else str(enabled).lower())
except:
    print('null')
" 2>/dev/null)
    fi

    if [[ "$enabled" != "true" ]]; then
        echo -e "${YELLOW}WARNING${NC} (mcp.enabled not set to true)"
        return 0
    fi

    # Read .meta.mcp.description
    local description
    if $use_yq; then
        description=$(yq eval '.meta.mcp.description' "$file" 2>/dev/null)
    else
        description=$(python3 -c "
import yaml
try:
    with open('$file') as f:
        doc = yaml.safe_load(f)
    desc = doc.get('meta', {}).get('mcp', {}).get('description')
    print('null' if desc is None or desc == '' else str(desc))
except:
    print('null')
" 2>/dev/null)
    fi

    if [[ "$description" == "null" || -z "$description" ]]; then
        echo -e "${RED}FAILED${NC} (missing description)"
        MCP_FAILS=$((MCP_FAILS + 1))
        return 1
    fi

    echo -e "${GREEN}PASSED${NC}"
    return 0
}

# Validate MCP metadata for each file
for file in resources/*/*.yaml; do
    if [[ -f "$file" ]]; then
        TOTAL=$((TOTAL + 1))
        echo ""
        echo -e "${BLUE}📄 Validating: $file${NC}"
        validate_mcp_metadata "$file"
    fi
done

# Summary
echo ""
echo "============================================"
echo "📊 Test Summary"
echo "============================================"
echo "Total configs tested: $TOTAL"
if [[ $MCP_FAILS -gt 0 ]]; then
    echo -e "MCP validation failures: ${RED}$MCP_FAILS${NC}"
fi
if [[ $SKIPPED -gt 0 ]]; then
    echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
fi
echo ""

if [[ $MCP_FAILS -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
