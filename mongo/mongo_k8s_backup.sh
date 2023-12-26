#!/bin/bash

##########################################################################################
# Script Name: mongo_k8s_backup.sh
# Description:
#    Automates the backup of a MongoDB database in a Kubernetes cluster.
#    It creates a timestamped backup, copies it to a specified location,
#    and cleans up old backups. Logs are written to both a file and the system log.
#
# Prerequisites:
#    - MongoDB database in a Kubernetes pod.
#    - 'kubectl' and 'mongodump' installed and configured.
#    - Necessary permissions for Kubernetes cluster and MongoDB.
#
# Usage: ./mongo_k8s_backup.sh <mongodb_password>
# Parameters:
#    <mongodb_password> - Password for the MongoDB root user.
#
# Author: Sudoix
# Date: December 26, 2023
# Version: 1.3
##########################################################################################

# Configurable Parameters
LOG_FILE="/var/log/mongo_backup.log"  # Log file path
SYSLOG_TAG="mongo_backup_script"     # Syslog tag
BACKUP_NAME="dbprod_$(date +%Y%m%d_%H%M%S)"  # Backup name
NAMESPACE="pro-marketer-db"  # Replace with your Kubernetes namespace
PODNAME="mongo-marketer-0"   # Replace with your Kubernetes pod name
BACKUP_DIR="/opt/mongo_bk"    # Replace with your desired backup directory
RETENTION_DAYS=3

# Function to log to both file and syslog
log_message() {
    local message=$1
    echo "[$(date)] $message" | tee -a $LOG_FILE
    logger -t $SYSLOG_TAG "$message"
}

# Check for required tools: kubectl
if ! command -v kubectl &> /dev/null; then
    log_message "Error: kubectl is not installed. Please install it and retry."
    exit 1
fi

# User-specified password
DB_PASSWORD=$1

# Validate password input
if [ -z "$DB_PASSWORD" ]; then
    log_message "Error: No database password provided. Usage: ./total_row.sh <mongodb_password>"
    exit 1
fi

# Logging start
log_message "Starting MongoDB backup process..."

# Backup process
if ! kubectl -n $NAMESPACE exec $PODNAME -- mongodump --archive=/tmp/$BACKUP_NAME.tar.gz -u root -p"$DB_PASSWORD" --authenticationDatabase=admin; then
    log_message "Backup failed"
    exit 1
fi

if ! kubectl -n $NAMESPACE cp $PODNAME:/tmp/$BACKUP_NAME.tar.gz $BACKUP_DIR/$BACKUP_NAME.tar.gz; then
    log_message "Backup copy failed"
    exit 1
fi

if ! kubectl -n $NAMESPACE exec $PODNAME -- rm -rf /tmp/$BACKUP_NAME.tar.gz; then
    log_message "Error removing temporary backup file from pod"
    exit 1
fi

# Cleanup old backups
log_message "Cleaning up old backups..."
if ! find $BACKUP_DIR/* -type f -mtime +$RETENTION_DAYS -delete; then
    log_message "Error cleaning up old backups"
    exit 1
fi

log_message "MongoDB backup process completed successfully."
