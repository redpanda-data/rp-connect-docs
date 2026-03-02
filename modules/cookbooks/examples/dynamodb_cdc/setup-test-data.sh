#!/bin/bash
# Setup script for DynamoDB CDC test environment
# Requires: aws cli, docker compose running

set -e

export AWS_ACCESS_KEY_ID=fakekey
export AWS_SECRET_ACCESS_KEY=fakesecret
export AWS_DEFAULT_REGION=us-east-1
ENDPOINT="http://localhost:8000"

echo "Waiting for DynamoDB Local to be ready..."
until aws dynamodb list-tables --endpoint-url $ENDPOINT > /dev/null 2>&1; do
  sleep 1
done
echo "DynamoDB Local is ready!"

echo "Creating test-users table with streams enabled..."
aws dynamodb create-table \
  --table-name test-users \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
  --endpoint-url $ENDPOINT \
  > /dev/null 2>&1 || echo "Table already exists, continuing..."

echo "Inserting test data..."

# Insert Alice
aws dynamodb put-item \
  --table-name test-users \
  --item '{"pk": {"S": "user#123"}, "sk": {"S": "profile"}, "name": {"S": "Alice"}, "email": {"S": "alice@example.com"}, "status": {"S": "active"}}' \
  --endpoint-url $ENDPOINT

# Insert Bob
aws dynamodb put-item \
  --table-name test-users \
  --item '{"pk": {"S": "user#456"}, "sk": {"S": "profile"}, "name": {"S": "Bob"}, "email": {"S": "bob@example.com"}, "status": {"S": "active"}}' \
  --endpoint-url $ENDPOINT

# Update Alice's name (generates MODIFY event)
aws dynamodb put-item \
  --table-name test-users \
  --item '{"pk": {"S": "user#123"}, "sk": {"S": "profile"}, "name": {"S": "Alice Smith"}, "email": {"S": "alice@example.com"}, "status": {"S": "active"}}' \
  --endpoint-url $ENDPOINT

# Delete Bob (generates REMOVE event)
aws dynamodb delete-item \
  --table-name test-users \
  --key '{"pk": {"S": "user#456"}, "sk": {"S": "profile"}}' \
  --endpoint-url $ENDPOINT

# Insert Charlie
aws dynamodb put-item \
  --table-name test-users \
  --item '{"pk": {"S": "user#789"}, "sk": {"S": "profile"}, "name": {"S": "Charlie"}, "email": {"S": "charlie@example.com"}, "status": {"S": "pending"}}' \
  --endpoint-url $ENDPOINT

echo ""
echo "Test data created! The following CDC events are available:"
echo "  1. INSERT - Alice created"
echo "  2. INSERT - Bob created"
echo "  3. MODIFY - Alice's name changed to 'Alice Smith'"
echo "  4. REMOVE - Bob deleted"
echo "  5. INSERT - Charlie created"
echo ""
echo "Run an example pipeline:"
echo "  rpk connect run basic-capture.yaml"
echo ""
echo "Or with custom endpoint:"
echo "  rpk connect run -s 'input.aws_dynamodb_cdc.endpoint=http://localhost:8000' \\"
echo "    -s 'input.aws_dynamodb_cdc.credentials.id=fakekey' \\"
echo "    -s 'input.aws_dynamodb_cdc.credentials.secret=fakesecret' \\"
echo "    basic-capture.yaml"
