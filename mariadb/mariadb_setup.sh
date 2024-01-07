##########################################################################################
# Script Name: mariadb_setup.sh
# Description:
#    This script automates the setup of a MariaDB database and table. It checks if the 
#    specified database and table exist, creates them if they do not, and then inserts 
#    sample data. The script uses credentials from a separate configuration file for 
#    enhanced security. It includes error handling to ensure each step is executed 
#    successfully.
#
# Prerequisites:
#    - MariaDB server installed and running.
#    - A user with sufficient privileges to create databases, tables, and insert data.
#    - 'mysql' client installed and configured.
#    - Database credentials provided in a 'db_config.cfg' file.
#
# Usage: ./mariadb_setup.sh
# Parameters: None. Edit the script to set database and table names, and the SQL statements.
#
# Author: Sudoix
# Date: January 07, 2024
# Version: 1.0
##########################################################################################

#!/bin/bash

# Load database configuration
source db_config.cfg

# Database and table names
DB_NAME="your_database_name"
TABLE_NAME="your_table_name"

# Function to execute SQL commands with error handling
execute_sql() {
    local sql=$1
    echo "Executing: $sql"
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -e "$sql"
    if [ $? -ne 0 ]; then
        echo "Error executing SQL: $sql"
        exit 1
    fi
}

# Create database if not exists
execute_sql "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
execute_sql "USE $DB_NAME;"

# Create table if not exists
# Replace the SQL statement below with your actual table creation SQL
execute_sql "CREATE TABLE IF NOT EXISTS $TABLE_NAME (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(255) NOT NULL
);"

# Insert data into the table
# Replace or expand this query to insert your desired data
execute_sql "INSERT INTO $TABLE_NAME (data) VALUES ('Sample Data');"

echo "Database and table setup complete. Data inserted."
