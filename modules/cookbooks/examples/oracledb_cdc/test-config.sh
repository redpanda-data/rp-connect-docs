#!/bin/bash
# Test configuration for Oracle CDC examples
# This file is sourced by ../test-examples.sh

# =============================================================================
# Unit Test Environment Variables
# =============================================================================
# Required for linting and rpk connect test
export ORACLE_CONNECTION_STRING="${ORACLE_CONNECTION_STRING:-oracle://cdc_user:CdcPassword123@localhost:1521/FREEPDB1}"
export REDPANDA_BROKERS="${REDPANDA_BROKERS:-localhost:9092}"
export S3_BUCKET="${S3_BUCKET:-test-bucket}"

# =============================================================================
# Integration Test Configuration
# =============================================================================
# Environment variables for rpk connect run
TEST_ENV_VARS="ORACLE_CONNECTION_STRING=oracle://cdc_user:CdcPassword123@localhost:1521/FREEPDB1 REDPANDA_BROKERS=localhost:9092 S3_BUCKET=test-cdc-bucket"

# Override flags to connect to local Docker services
TEST_OVERRIDES="-s 'output.aws_s3.endpoint=http://localhost:4566' \
  -s 'output.aws_s3.region=us-east-1' \
  -s 'output.aws_s3.credentials.id=test' \
  -s 'output.aws_s3.credentials.secret=test' \
  -s 'output.aws_s3.force_path_style_urls=true'"

# Timeout per test (seconds)
TEST_TIMEOUT=20

# =============================================================================
# Reset Between Tests
# =============================================================================
# Called after each integration test to reset state
reset_between_tests() {
  # No cleanup needed between Oracle tests
  # Each test uses the same database state
  :
}
