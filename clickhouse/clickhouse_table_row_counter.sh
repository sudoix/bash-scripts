#!/bin/bash

##########################################################################################
# Script Name: clickhouse_table_row_counter.sh
# Description:
#    This script is designed to count and record the number of rows for each user ID
#    across all tables in each database within a ClickHouse server, focusing on data
#    from the last month. It iterates over each database and table, performing a count
#    query for each user ID specified in a separate text file. The results are then
#    compiled into a CSV file, detailing the user ID, database, table, and the corresponding
#    row count. This script is useful for analyzing user activity and data spread
#    across multiple tables and databases in a ClickHouse environment.
#
# Prerequisites:
#    - Access to a ClickHouse server with one or more databases containing user data.
#    - A text file named 'user.txt' containing user IDs, one per line.
#    - The 'clickhouse-client' tool installed for executing queries on the ClickHouse server.
#    - Appropriate permissions to query all relevant databases and tables.
#
# Usage: ./clickhouse_table_row_counter.sh
# Parameters:
#    None. The script autonomously reads user IDs from 'user.txt' and connects to the
#    ClickHouse server using specified host and port details.
#
# Output File:
#    database_rows_count.csv - Contains columns for User ID, Database, Table, and Row Count.
#
# Author: [Your Name]
# Date: [Date of Script Creation]
# Version: 1.0
##########################################################################################


# Define your ClickHouse connection details
CH_HOST="YOUR SERVER IP OR NAME"
CH_PORT="9000"

# Output file
OUTPUT_FILE="database_rows_count.csv"

# Log file setup
LOG_DIR="/var/log/clickhouse_stats"
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/clickhouse_stats_$(date +'%Y%m%d').log"

# Function to write logs
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Start of the script log
log "Starting ClickHouse table row counter script."

# Write header to the output file
echo "User ID,Database,Table,Count" > "$OUTPUT_FILE"
log "CSV header written to $OUTPUT_FILE."

# Get a list of databases
log "Retrieving list of databases."
DATABASES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SHOW DATABASES" | grep -v system)

# Read user IDs from user.txt file
log "Reading user IDs from user.txt."
USER_IDS=$(cat user.txt)

# Loop through the databases
for DATABASE in $DATABASES; do
    log "Processing database: $DATABASE."

    # Get a list of tables for the current database
    TABLES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SHOW TABLES FROM $DATABASE")

    # Loop through each table
    for TABLE in $TABLES; do
        log "Processing table: $TABLE in database $DATABASE."

        # Loop through each user ID
        for USER_ID in $USER_IDS; do
            # Query to count rows for the user ID in the last month in the current table
            QUERY="SELECT COUNT(*) FROM $DATABASE.$TABLE WHERE user_id = '$USER_ID' AND time >= now() - INTERVAL 1 MONTH"

            # Execute the query and get the count
            log "Executing query for user ID $USER_ID in table $TABLE."
            COUNT=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "$QUERY")

            # Check for query success
            if [ $? -eq 0 ]; then
                log "Query successful. Count for user ID $USER_ID: $COUNT"
            else
                log "Query failed for user ID $USER_ID in table $TABLE."
            fi

            # Output the result in CSV format
            echo "$USER_ID,$DATABASE,$TABLE,$COUNT" >> "$OUTPUT_FILE"
        done
    done
done

log "Script execution completed. Output file: $OUTPUT_FILE."