#!/bin/bash

##########################################################################################
# Script Name: read.sh
# Description: This Bash script connects to a ClickHouse database server
# using provided connection details and retrieves a list of databases, tables, and rows.
# Author: Sudoix
# Date: December 25, 2023
# Version: 1.0
#
# This script assumes you have the clickhouse-client tool installed on your system,\
# which is used to interact with the ClickHouse server via SQL queries.
##########################################################################################

# Define your ClickHouse connection details
CH_HOST="YOUR SERVER IP OR NAME"
CH_PORT="9000"
# CH_USER="your_user"
# CH_PASSWORD="your_password"

# Get a list of databases
DATABASES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "SHOW DATABASES" | grep -v system)
echo $DATABASES


# Loop through the databases
for DATABASE in $DATABASES; do
    # Set the current database
    CH_DATABASE="$DATABASE"
    echo "Using database $CH_DATABASE" >> listdatabases.txt
    # Get a list of tables in the current database
    TABLES=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT"  --database "$CH_DATABASE" --query "SHOW TABLES")

    # Initialize a variable to store the total row count for the current database
    TOTAL_ROW_COUNT=0

    # Loop through the tables in the current database
    for TABLE in $TABLES; do
        # Get the row count for the current table
        ROW_COUNT=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT"  --database "$CH_DATABASE" --query "SELECT COUNT(*) FROM $TABLE")
        echo "Database: $DATABASE, Table: $TABLE, Row Count: $ROW_COUNT" >> row_count.txt

        # Add the row count to the total for the current database
        TOTAL_ROW_COUNT=$((TOTAL_ROW_COUNT + ROW_COUNT))
    done

    # Print the total row count for the current database
    echo "Database: $DATABASE, Total Row Count: $TOTAL_ROW_COUNT" >> total_row_count.txt

    # Add the total row count for the current database to the grand total
    GRAND_TOTAL_ROW_COUNT=$((GRAND_TOTAL_ROW_COUNT + TOTAL_ROW_COUNT))
    echo "Total row of all databases is: $GRAND_TOTAL_ROW_COUNT" >>  total.txt

    # Calculate the total size of the current database and add it to the total database size
    DATABASE_SIZE=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --database "$CH_DATABASE" --query "SELECT formatReadableSize(sum(bytes)) FROM system.parts")

    # Print the total size of the current database
    echo "Database: $CH_DATABASE, Total Size: $DATABASE_SIZE"
done

# Print the grand total row count and total database size
echo "Grand Total Row Count: $GRAND_TOTAL_ROW_COUNT"
echo "Total Database Size: $DATABASE_SIZE"
