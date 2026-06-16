#!/bin/bash
# Test configuration for BigQuery Storage Write API examples
# This file is sourced by ../test-examples.sh

# =============================================================================
# Unit Test Environment Variables
# =============================================================================
# Required for linting and rpk connect test. The values are placeholders: unit
# tests target the pipeline processors with mock inputs and outputs, so no real
# Redpanda cluster or Google Cloud project is contacted.
export REDPANDA_BROKERS="${REDPANDA_BROKERS:-localhost:9092}"
export SOURCE_TOPIC="${SOURCE_TOPIC:-events}"
export GCP_PROJECT="${GCP_PROJECT:-test-project}"
export BQ_DATASET="${BQ_DATASET:-analytics}"
export BQ_TABLE="${BQ_TABLE:-events}"

# =============================================================================
# Integration Test Configuration
# =============================================================================
# No integration (smoke) tests are provided for this cookbook: the
# gcp_bigquery_write_api output requires a real Google Cloud project and
# BigQuery dataset, which cannot be emulated with Docker Compose. Only unit
# tests run for these examples.

# Timeout per test (seconds)
TEST_TIMEOUT=20
