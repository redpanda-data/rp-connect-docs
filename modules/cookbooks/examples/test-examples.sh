#!/bin/bash
# Test script for cookbook examples
#
# Usage:
#   ./test-examples.sh                    # Test all examples
#   ./test-examples.sh --unit-only        # Only run unit tests
#   ./test-examples.sh --integration-only # Only run integration tests
#   ./test-examples.sh dynamodb_cdc       # Test specific category
#
# Adding a new cookbook:
#   1. Create a directory: my_cookbook/
#   2. Add YAML pipeline files with inline tests (see rpk connect test docs)
#   3. (Optional) Add test-config.sh for environment variables
#   4. (Optional) Add docker-compose.yaml for integration tests
#   5. (Optional) Add setup-test-data.sh for test data setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Options
UNIT_ONLY=false
INTEGRATION_ONLY=false
CATEGORY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --unit-only)
      UNIT_ONLY=true
      shift
      ;;
    --integration-only)
      INTEGRATION_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS] [CATEGORY]"
      echo ""
      echo "Options:"
      echo "  --unit-only         Only run unit tests (rpk connect test)"
      echo "  --integration-only  Only run integration tests (Docker Compose)"
      echo "  --help, -h          Show this help message"
      echo ""
      echo "Arguments:"
      echo "  CATEGORY  Category directory name like 'dynamodb_cdc' or 'jira'"
      echo ""
      echo "Adding a new cookbook:"
      echo "  1. Create a directory with YAML pipeline files"
      echo "  2. Add inline tests to your YAML files (rpk connect test)"
      echo "  3. (Optional) Create test-config.sh - see dynamodb_cdc/test-config.sh"
      echo "  4. (Optional) Create docker-compose.yaml for integration tests"
      echo "  5. (Optional) Create setup-test-data.sh for test data"
      exit 0
      ;;
    *)
      if [[ -d "$1" ]]; then
        CATEGORY="$1"
      else
        echo "Unknown option or directory not found: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

# Find all example directories
find_example_dirs() {
  if [[ -n "$CATEGORY" ]]; then
    if [[ -d "$CATEGORY" ]]; then
      echo "$CATEGORY"
    else
      log_error "Category directory not found: $CATEGORY"
      exit 1
    fi
  else
    find . -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sed 's|^\./||' | sort
  fi
}

# Check if a directory has a docker-compose.yaml
has_docker_compose() {
  [[ -f "$1/docker-compose.yaml" ]] || [[ -f "$1/docker-compose.yml" ]]
}

# Check if a directory has a test-config.sh
has_test_config() {
  [[ -f "$1/test-config.sh" ]]
}

# Load test configuration for a directory
# Sets: TEST_ENV_VARS, TEST_OVERRIDES, TEST_TIMEOUT, reset_between_tests()
load_test_config() {
  local dir="$1"

  # Reset to defaults
  TEST_ENV_VARS=""
  TEST_OVERRIDES=""
  TEST_TIMEOUT=20

  # Define default reset function (no-op)
  reset_between_tests() { :; }

  if has_test_config "$dir"; then
    # Source the config file to load variables and functions
    source "$dir/test-config.sh"
    log_info "Loaded test-config.sh"
  else
    # Fall back to generic defaults
    export KAFKA_BROKERS="${KAFKA_BROKERS:-localhost:9092}"
    export AWS_REGION="${AWS_REGION:-us-east-1}"
  fi
}

# Run unit tests for a directory
run_unit_tests() {
  local dir="$1"

  # Load test config (sets environment variables)
  load_test_config "$dir"

  local yaml_files=$(ls "$dir"/*.yaml 2>/dev/null | grep -v docker-compose || true)

  if [[ -z "$yaml_files" ]]; then
    log_skip "No YAML files found in $dir"
    return 0
  fi

  log_info "Running unit tests in $dir..."

  local dir_passed=0
  local dir_failed=0

  for config_file in $yaml_files; do
    [[ "$(basename "$config_file")" == "docker-compose"* ]] && continue

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    local basename=$(basename "$config_file")

    # Lint the config
    if ! rpk connect lint --skip-env-var-check "$config_file" > /dev/null 2>&1; then
      log_error "$basename - lint failed"
      rpk connect lint --skip-env-var-check "$config_file" 2>&1 | head -3
      FAILED_TESTS=$((FAILED_TESTS + 1))
      dir_failed=$((dir_failed + 1))
      continue
    fi

    # Run unit tests
    if rpk connect test "$config_file" > /dev/null 2>&1; then
      log_success "$basename"
      PASSED_TESTS=$((PASSED_TESTS + 1))
      dir_passed=$((dir_passed + 1))
    else
      if rpk connect test "$config_file" 2>&1 | grep -q "no tests"; then
        log_skip "$basename - no tests defined"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS - 1))
      else
        log_error "$basename - test failed"
        rpk connect test "$config_file" 2>&1 | tail -5
        FAILED_TESTS=$((FAILED_TESTS + 1))
        dir_failed=$((dir_failed + 1))
      fi
    fi
  done

  [[ $dir_failed -eq 0 ]] && [[ $dir_passed -gt 0 ]] && \
    log_info "All unit tests passed in $dir ($dir_passed tests)"

  return $dir_failed
}

# Run integration tests for a directory with docker-compose
run_integration_tests() {
  local dir="$1"

  if ! has_docker_compose "$dir"; then
    log_skip "No docker-compose.yaml in $dir - skipping integration tests"
    return 0
  fi

  log_info "Running integration tests in $dir..."
  cd "$dir"

  # Load test configuration
  load_test_config "."

  # Start Docker Compose services
  log_info "Starting Docker services..."
  if ! docker compose up -d --wait; then
    log_error "Failed to start Docker services"
    docker compose logs
    docker compose down -v 2>/dev/null || true
    cd "$SCRIPT_DIR"
    return 1
  fi

  # Run setup script if it exists
  if [[ -x "setup-test-data.sh" ]]; then
    log_info "Running setup script..."
    if ! ./setup-test-data.sh; then
      log_error "Setup script failed"
      docker compose down -v 2>/dev/null || true
      cd "$SCRIPT_DIR"
      return 1
    fi
  fi

  # Run integration tests for each YAML file
  local integration_failed=0
  local yaml_files=$(ls *.yaml 2>/dev/null | grep -v docker-compose || true)

  for config_file in $yaml_files; do
    log_info "Integration test: $config_file"

    # Build the command with env vars and overrides from config
    local cmd="$TEST_ENV_VARS rpk connect run $TEST_OVERRIDES $config_file"

    # Run the pipeline with timeout
    if timeout "${TEST_TIMEOUT}s" bash -c "$cmd" > /tmp/integration-output.txt 2>&1; then
      log_success "$config_file - integration test passed"
    else
      local exit_code=$?
      # Timeout (124/137) is expected - we're testing the pipeline starts and processes
      if [[ $exit_code -eq 124 ]] || [[ $exit_code -eq 137 ]]; then
        if grep -q "Input type" /tmp/integration-output.txt && ! grep -qi "error" /tmp/integration-output.txt; then
          log_success "$config_file - integration test passed (timed out as expected)"
        else
          log_error "$config_file - integration test failed"
          cat /tmp/integration-output.txt
          integration_failed=$((integration_failed + 1))
        fi
      else
        log_error "$config_file - integration test failed with exit code $exit_code"
        cat /tmp/integration-output.txt
        integration_failed=$((integration_failed + 1))
      fi
    fi

    # Run reset function between tests (defined in test-config.sh)
    reset_between_tests
  done

  # Cleanup
  log_info "Stopping Docker services..."
  docker compose down -v 2>/dev/null || true
  cd "$SCRIPT_DIR"

  if [[ $integration_failed -gt 0 ]]; then
    log_error "Integration tests failed in $dir ($integration_failed failures)"
    return 1
  else
    log_success "All integration tests passed in $dir"
    return 0
  fi
}

# Main execution
main() {
  log_info "Starting cookbook example tests..."
  echo ""

  local example_dirs
  example_dirs=$(find_example_dirs)

  if [[ -z "$example_dirs" ]]; then
    log_warning "No example directories found"
    exit 0
  fi

  local overall_failed=0

  for dir in $example_dirs; do
    echo ""
    echo "=========================================="
    echo "Testing: $dir"
    echo "=========================================="

    # Run unit tests
    if [[ "$INTEGRATION_ONLY" != "true" ]]; then
      run_unit_tests "$dir" || overall_failed=1
    fi

    # Run integration tests
    if [[ "$UNIT_ONLY" != "true" ]] && has_docker_compose "$dir"; then
      run_integration_tests "$dir" || overall_failed=1
    fi
  done

  echo ""
  echo "=========================================="
  echo "Test Summary"
  echo "=========================================="
  echo -e "Total:   $TOTAL_TESTS"
  echo -e "Passed:  ${GREEN}$PASSED_TESTS${NC}"
  echo -e "Failed:  ${RED}$FAILED_TESTS${NC}"
  echo -e "Skipped: ${YELLOW}$SKIPPED_TESTS${NC}"
  echo ""

  if [[ $FAILED_TESTS -gt 0 ]] || [[ $overall_failed -gt 0 ]]; then
    log_error "Some tests failed"
    exit 1
  else
    log_success "All tests passed!"
    exit 0
  fi
}

main
