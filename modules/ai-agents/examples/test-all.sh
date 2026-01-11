#!/usr/bin/env bash
#
# Master test script for all Redpanda Connect MCP examples
#
# This script tests:
# 1. MCP tool definitions using `rpk connect mcp-server lint`
# 2. Full pipelines using `rpk connect run`
# 3. Config snippets using `rpk connect lint`
#
# Usage:
#   ./test-all.sh              # Run all tests
#   ./test-all.sh --mcp-only   # Only test MCP tools
#   ./test-all.sh --pipelines  # Only test pipelines
#   ./test-all.sh --snippets   # Only test snippets

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Counters
TOTAL_MCP=0
PASSED_MCP=0
TOTAL_PIPELINES=0
PASSED_PIPELINES=0
TOTAL_SNIPPETS=0
PASSED_SNIPPETS=0

echo "🧪 Redpanda Connect Examples - Complete Test Suite"
echo "=================================================="
echo ""

# Parse arguments
RUN_MCP=true
RUN_PIPELINES=true
RUN_SNIPPETS=true

if [[ $# -gt 0 ]]; then
    case "$1" in
        --mcp-only)
            RUN_PIPELINES=false
            RUN_SNIPPETS=false
            ;;
        --pipelines)
            RUN_MCP=false
            RUN_SNIPPETS=false
            ;;
        --snippets)
            RUN_MCP=false
            RUN_PIPELINES=false
            ;;
    esac
fi

# ============================================================================
# SECTION 1: MCP Tool Definitions
# These are complete MCP tools that should be tested with mcp-server lint
# rpk connect mcp-server lint works on directories, so we test each directory
# ============================================================================

if $RUN_MCP; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📦 ${CYAN}SECTION 1: MCP Tool Definitions${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Directories containing MCP tool definitions
    MCP_DIRS=(
        "resources/inputs"
        "resources/outputs"
        "resources/processors"
        "best-practices/mcp-metadata"
        "best-practices/production-workflows"
        "best-practices/tool-implementation"
    )

    for dir in "${MCP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            file_count=$(find "$dir" -name "*.yaml" | wc -l | tr -d ' ')
            TOTAL_MCP=$((TOTAL_MCP + file_count))

            echo -n -e "${BLUE}📁 $dir${NC} ($file_count files)... "

            if output=$(rpk connect mcp-server lint --skip-env-var-check "$dir" 2>&1); then
                echo -e "${GREEN}✓ PASSED${NC}"
                PASSED_MCP=$((PASSED_MCP + file_count))
            else
                echo -e "${RED}✗ FAILED${NC}"
                echo "$output" | sed 's/^/   /' | head -10
                echo ""
            fi
        fi
    done
fi

# ============================================================================
# SECTION 2: Full Pipelines (runnable examples)
# These have input/pipeline/output and can be executed with rpk connect run
# ============================================================================

if $RUN_PIPELINES; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "🔄 ${CYAN}SECTION 2: Full Pipelines${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    PIPELINE_DIRS=(
        "best-practices/input-validation"
        "best-practices/response-formatting"
        "best-practices/error-handling"
    )

    for dir in "${PIPELINE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo -e "${BLUE}📁 Testing: $dir${NC}"

            for file in "$dir"/*.yaml; do
                if [[ -f "$file" ]]; then
                    TOTAL_PIPELINES=$((TOTAL_PIPELINES + 1))
                    filename=$(basename "$file")
                    echo -n "   $filename "

                    # First lint
                    echo -n "[lint: "
                    if rpk connect lint --skip-env-var-check "$file" > /dev/null 2>&1; then
                        echo -n -e "${GREEN}✓${NC}] "
                    else
                        echo -e "${RED}✗${NC}]"
                        rpk connect lint --skip-env-var-check "$file" 2>&1 | sed 's/^/      /'
                        continue
                    fi

                    # Then run
                    echo -n "[run: "
                    if timeout 30s rpk connect run "$file" > /dev/null 2>&1; then
                        echo -e "${GREEN}✓${NC}]"
                        PASSED_PIPELINES=$((PASSED_PIPELINES + 1))
                    else
                        echo -e "${RED}✗${NC}]"
                    fi
                fi
            done
            echo ""
        fi
    done
fi

# ============================================================================
# SECTION 3: Config Snippets
# These are partial configs or examples that may not run but should lint
# ============================================================================

if $RUN_SNIPPETS; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📝 ${CYAN}SECTION 3: Config Snippets${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    SNIPPET_DIRS=(
        "best-practices/debugging"
        "best-practices/error-handling-snippets"
        "best-practices/config-examples"
    )

    for dir in "${SNIPPET_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            file_count=$(find "$dir" -name "*.yaml" | wc -l | tr -d ' ')
            TOTAL_SNIPPETS=$((TOTAL_SNIPPETS + file_count))

            echo -n -e "${BLUE}📁 $dir${NC} ($file_count files)... "

            # Try MCP lint on directory (these should be MCP tools)
            if output=$(rpk connect mcp-server lint --skip-env-var-check "$dir" 2>&1); then
                echo -e "${GREEN}✓ PASSED${NC} (mcp)"
                PASSED_SNIPPETS=$((PASSED_SNIPPETS + file_count))
            else
                echo -e "${RED}✗ FAILED${NC}"
                echo "$output" | sed 's/^/   /' | head -10
            fi
        fi
    done

    # Handle o11y separately (these are just config fragments)
    if [[ -d "o11y" ]]; then
        echo ""
        echo -e "${BLUE}📁 o11y (config fragments)${NC}"

        for file in o11y/*.yaml; do
            if [[ -f "$file" ]]; then
                TOTAL_SNIPPETS=$((TOTAL_SNIPPETS + 1))
                filename=$(basename "$file")
                echo -n "   $filename... "

                # These are just YAML fragments - check valid YAML
                if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                    echo -e "${GREEN}✓${NC} (yaml)"
                    PASSED_SNIPPETS=$((PASSED_SNIPPETS + 1))
                else
                    echo -e "${RED}✗${NC} (invalid yaml)"
                fi
            fi
        done
        echo ""
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "=================================================="
echo "📊 Test Summary"
echo "=================================================="

TOTAL=$((TOTAL_MCP + TOTAL_PIPELINES + TOTAL_SNIPPETS))
PASSED=$((PASSED_MCP + PASSED_PIPELINES + PASSED_SNIPPETS))
FAILED=$((TOTAL - PASSED))

if $RUN_MCP; then
    echo -e "MCP Tools:    ${PASSED_MCP}/${TOTAL_MCP} passed"
fi
if $RUN_PIPELINES; then
    echo -e "Pipelines:    ${PASSED_PIPELINES}/${TOTAL_PIPELINES} passed"
fi
if $RUN_SNIPPETS; then
    echo -e "Snippets:     ${PASSED_SNIPPETS}/${TOTAL_SNIPPETS} passed"
fi
echo "──────────────────────────────────────────────────"
echo -e "Total:        ${PASSED}/${TOTAL} passed"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}❌ Some tests failed ($FAILED failures)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
fi
