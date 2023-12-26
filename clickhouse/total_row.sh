#!/bin/bash

##########################################################################################
# Script Name: total_row.sh
# Description: This Bash script connects to a ClickHouse database server, retrieves and 
# logs details of databases, tables, row counts, and sizes.
# Author: Sudoix
# Date: December 25, 2023
# Version: 2.0
#
# Dependencies: clickhouse-client
##########################################################################################

# ClickHouse connection details
CH_HOST="YOUR SERVER IP OR NAME"
CH_PORT="9000"
# CH_USER="your_user"
# CH_PASSWORD="your_password"

# Log file setup
LOG_DIR="/var/log/clickhouse_stats"
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/clickhouse_stats_$(date +'%Y%m%d').log"

# Function to write logs
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Retrieve and log database list
log "Retrieving list of databases..."
DATABASES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SHOW DATABASES" | grep -v system)
log "Databases found: $DATABASES"

# Initialize grand total variables
GRAND_TOTAL_ROW_COUNT=0
GRAND_TOTAL_SIZE=0

# Process each database
for DATABASE in $DATABASES; do
    CH_DATABASE="$DATABASE"
    log "Processing database: $CH_DATABASE"

    # Retrieve and log table list
    TABLES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --database "$CH_DATABASE" --query "SHOW TABLES")
    log "Tables in $CH_DATABASE: $TABLES"

    TOTAL_ROW_COUNT=0
    TOTAL_DB_SIZE=0

    # Process each table
    for TABLE in $TABLES; do
        ROW_COUNT=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --database "$CH_DATABASE" --query "SELECT COUNT(*) FROM $TABLE")
        log "Database: $DATABASE, Table: $TABLE, Row Count: $ROW_COUNT"

        TOTAL_ROW_COUNT=$((TOTAL_ROW_COUNT + ROW_COUNT))
    done

    # Log total row count for the database
    log "Database: $DATABASE, Total Row Count: $TOTAL_ROW_COUNT"
    GRAND_TOTAL_ROW_COUNT=$((GRAND_TOTAL_ROW_COUNT + TOTAL_ROW_COUNT))

    # Calculate and log total size of the database
    DATABASE_SIZE=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --database "$CH_DATABASE" --query "SELECT formatReadableSize(sum(bytes)) FROM system.parts")
    log "Database: $CH_DATABASE, Total Size: $DATABASE_SIZE"

    # Update grand totals
    GRAND_TOTAL_SIZE=$(echo "$GRAND_TOTAL_SIZE + $DATABASE_SIZE" | bc)
done

# Log grand totals
log "Grand Total Row Count: $GRAND_TOTAL_ROW_COUNT"
log "Grand Total Database Size: $GRAND_TOTAL_SIZE"
