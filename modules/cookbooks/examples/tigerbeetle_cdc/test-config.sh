#!/bin/bash
# Test configuration for TigerBeetle CDC examples
# This file is sourced by ../test-examples.sh

# =============================================================================
# Unit Test Environment Variables
# =============================================================================
export TB_CLUSTER_ID="${TB_CLUSTER_ID:-0}"
export TB_REPLICA_1="${TB_REPLICA_1:-localhost:3000}"
export TB_REPLICA_2="${TB_REPLICA_2:-localhost:3001}"
export TB_REPLICA_3="${TB_REPLICA_3:-localhost:3002}"
export REDPANDA_BROKERS="${REDPANDA_BROKERS:-localhost:9092}"
export S3_BUCKET="${S3_BUCKET:-test-bucket}"
export REDIS_URL="${REDIS_URL:-redis://localhost:6379}"

# =============================================================================
# Skip lint: tigerbeetle_cdc requires a cgo-enabled binary and is not
# recognized by the standard rpk connect linter.
# =============================================================================
SKIP_LINT=true
