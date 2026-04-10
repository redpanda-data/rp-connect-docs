#!/bin/bash
set -e

echo "=== Setting up Oracle Database for CDC Testing ==="

# Wait for Oracle to be ready
echo "Waiting for Oracle to be ready..."
until docker exec oracle-cdc-test healthcheck.sh >/dev/null 2>&1; do
  printf '.'
  sleep 2
done
echo " Oracle is ready!"

# Execute SQL setup
docker exec oracle-cdc-test sqlplus -S system/TestPassword123@localhost:1521/FREEPDB1 <<'EOF'
SET ECHO ON
SET SERVEROUTPUT ON

-- Enable supplemental logging at database level
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Enable archivelog mode (already enabled in gvenzl/oracle-free image)

-- Create CDC user with permissions
CREATE USER cdc_user IDENTIFIED BY CdcPassword123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO cdc_user;
GRANT SELECT ANY TABLE TO cdc_user;
GRANT SELECT_CATALOG_ROLE TO cdc_user;
GRANT EXECUTE_CATALOG_ROLE TO cdc_user;
GRANT SELECT ANY TRANSACTION TO cdc_user;
GRANT LOGMINING TO cdc_user;
GRANT FLASHBACK ANY TABLE TO cdc_user;

-- Create schema for CDC checkpoints
CREATE USER rpcn IDENTIFIED BY RpcnPassword123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE TABLE TO rpcn;
GRANT CREATE PROCEDURE TO rpcn;
GRANT CREATE SEQUENCE TO rpcn;

-- Grant cdc_user access to rpcn schema
GRANT SELECT, INSERT, UPDATE, DELETE ON rpcn.CDC_CHECKPOINT_CACHE TO cdc_user;

-- Create test schema
CREATE USER my_schema IDENTIFIED BY MySchemaPassword123 DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO my_schema;
GRANT CREATE TABLE TO my_schema;
GRANT CREATE SEQUENCE TO my_schema;

-- Connect as my_schema to create tables
CONNECT my_schema/MySchemaPassword123@localhost:1521/FREEPDB1

-- Create ORDERS table
CREATE TABLE ORDERS (
  ID NUMBER PRIMARY KEY,
  CUSTOMER_NAME VARCHAR2(100),
  TOTAL NUMBER(10,2),
  STATUS VARCHAR2(50),
  CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enable supplemental logging for ORDERS table
ALTER TABLE ORDERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Create CUSTOMERS table
CREATE TABLE CUSTOMERS (
  ID NUMBER PRIMARY KEY,
  NAME VARCHAR2(100),
  EMAIL VARCHAR2(100),
  CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enable supplemental logging for CUSTOMERS table
ALTER TABLE CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Grant access to cdc_user
GRANT SELECT ON ORDERS TO cdc_user;
GRANT SELECT ON CUSTOMERS TO cdc_user;

-- Insert test data
INSERT INTO ORDERS (ID, CUSTOMER_NAME, TOTAL, STATUS) VALUES (1, 'Alice', 99.99, 'pending');
INSERT INTO ORDERS (ID, CUSTOMER_NAME, TOTAL, STATUS) VALUES (2, 'Bob', 149.99, 'shipped');
INSERT INTO ORDERS (ID, CUSTOMER_NAME, TOTAL, STATUS) VALUES (3, 'Charlie', 79.99, 'completed');

INSERT INTO CUSTOMERS (ID, NAME, EMAIL) VALUES (1, 'Alice', 'alice@example.com');
INSERT INTO CUSTOMERS (ID, NAME, EMAIL) VALUES (2, 'Bob', 'bob@example.com');

COMMIT;

-- Show created objects
SELECT 'ORDERS table created with ' || COUNT(*) || ' rows' FROM ORDERS;
SELECT 'CUSTOMERS table created with ' || COUNT(*) || ' rows' FROM CUSTOMERS;

EXIT;
EOF

echo ""
echo "=== Oracle CDC Test Environment Ready ==="
echo "Connection string: oracle://cdc_user:CdcPassword123@localhost:1521/FREEPDB1"
echo "Tables: MY_SCHEMA.ORDERS, MY_SCHEMA.CUSTOMERS"
echo ""
echo "To make changes to the database:"
echo "docker exec -it oracle-cdc-test sqlplus my_schema/MySchemaPassword123@localhost:1521/FREEPDB1"
echo ""
echo "Example operations:"
echo "  INSERT INTO ORDERS (ID, CUSTOMER_NAME, TOTAL, STATUS) VALUES (4, 'David', 199.99, 'pending');"
echo "  UPDATE ORDERS SET STATUS = 'shipped' WHERE ID = 1;"
echo "  DELETE FROM ORDERS WHERE ID = 3;"
echo "  COMMIT;"
