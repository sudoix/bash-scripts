#!/bin/bash

##########################################################################################
# Script Name: clickhouse_user_data_aggregator.sh
# Description:
#    This script aggregates data from a ClickHouse database, focusing on user-specific data.
#    It reads user IDs from a file, retrieves their associated domain from a specified table,
#    and calculates the total number of rows for each user ID across all tables in the database
#    for the past month. The script outputs these details to a CSV file, providing a clear
#    overview of user engagement and activity.
#
# Prerequisites:
#    - ClickHouse database with accessible tables containing user data.
#    - User IDs stored in a text file named 'user.txt'.
#    - The 'clickhouse-client' command-line tool installed and configured for database access.
#    - Necessary permissions to access the database and execute queries.
#
# Usage: ./clickhouse_user_data_aggregator.sh
# Parameters:
#    None. The script reads user IDs from 'user.txt' and connects to the database using predefined
#    host and port variables.
#
# Output File:
#    user_rows_count.csv - Contains columns for User ID, User Domain, and Total Count.
#
# Author: Sudoix
# Date: December 26, 2023
# Version: 1.0
##########################################################################################



# Define your ClickHouse connection details
CH_HOST="Your Server IP or Name"
CH_PORT="9000"

# Output file
OUTPUT_FILE="user_rows_count.csv"

# Log file setup
LOG_DIR="/var/log/clickhouse_user_stats"
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/clickhouse_user_stats_$(date +'%Y%m%d').log"

# Function to write logs
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Start of the script log
log "Starting user row count aggregation script."

# Write header to the output file
echo "User ID,User Domain,Total Count" > "$OUTPUT_FILE"
log "CSV header written to $OUTPUT_FILE."

# Get a list of databases
log "Retrieving list of databases."
DATABASES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SHOW DATABASES" | grep -v system)

# Read user IDs from user.txt file
log "Reading user IDs from user.txt."
USER_IDS=$(cat user.txt)

# Loop through each user ID
for USER_ID in $USER_IDS; do
    log "Processing user ID: $USER_ID."
    TOTAL_COUNT=0

    # Retrieve domain for the user ID
    log "Retrieving domain for user ID: $USER_ID."
    DOMAIN=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SELECT domain FROM vod.vod_rich_requests_daily WHERE user_id = '$USER_ID' LIMIT 1" 2>/dev/null) # Change vod and 'vod_rich_requests_daily' to the appropriate database and table name

    # Loop through the databases
    for DATABASE in $DATABASES; do
        log "Processing database: $DATABASE."

        # Get a list of tables for the current database
        TABLES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SHOW TABLES FROM $DATABASE")

        # Loop through each table
        for TABLE in $TABLES; do
            log "Processing table: $TABLE in database $DATABASE."

            # Query to count rows for the user ID in the last month in the current table
            QUERY="SELECT COUNT(*) FROM $DATABASE.$TABLE WHERE user_id = '$USER_ID' AND time >= now() - INTERVAL 1 MONTH"

            # Execute the query and get the count
            COUNT=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "$QUERY" 2>/dev/null)

            # Add count to total count for the user ID
            TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
            log "Updated total count for user ID $USER_ID: $TOTAL_COUNT."
        done
    done

    # Output the total count for the user ID
    log "Final count for user ID $USER_ID is $TOTAL_COUNT."
    echo "$USER_ID,$DOMAIN,$TOTAL_COUNT"
    echo "$USER_ID,$DOMAIN,$TOTAL_COUNT" >> "$OUTPUT_FILE"
done

log "Script execution completed. Output file: $OUTPUT_FILE."