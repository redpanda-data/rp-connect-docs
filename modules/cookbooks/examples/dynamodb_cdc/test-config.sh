#!/bin/bash
# Test configuration for DynamoDB CDC examples
# This file is sourced by ../test-examples.sh

# =============================================================================
# Unit Test Environment Variables
# =============================================================================
# Required for linting and rpk connect test
export DYNAMODB_TABLE="${DYNAMODB_TABLE:-test-table}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export REDPANDA_BROKERS="${REDPANDA_BROKERS:-localhost:9092}"
export S3_BUCKET="${S3_BUCKET:-test-bucket}"

# =============================================================================
# Integration Test Configuration
# =============================================================================
# Environment variables for rpk connect run
TEST_ENV_VARS="DYNAMODB_TABLE=test-users AWS_REGION=us-east-1 REDPANDA_BROKERS=localhost:9092 S3_BUCKET=test-cdc-bucket"

# Override flags to connect to local Docker services
TEST_OVERRIDES="-s 'input.aws_dynamodb_cdc.endpoint=http://localhost:8000' \
  -s 'input.aws_dynamodb_cdc.credentials.id=fakekey' \
  -s 'input.aws_dynamodb_cdc.credentials.secret=fakesecret' \
  -s 'input.aws_dynamodb_cdc.start_from=trim_horizon'"

# Timeout per test (seconds)
TEST_TIMEOUT=20

# =============================================================================
# Reset Between Tests
# =============================================================================
# Called after each integration test to reset state
reset_between_tests() {
  # Delete checkpoint table so next test starts fresh
  AWS_ACCESS_KEY_ID=fakekey \
  AWS_SECRET_ACCESS_KEY=fakesecret \
  AWS_DEFAULT_REGION=us-east-1 \
    aws dynamodb delete-table \
      --table-name redpanda_dynamodb_checkpoints \
      --endpoint-url http://localhost:8000 2>/dev/null || true
  sleep 1
}
