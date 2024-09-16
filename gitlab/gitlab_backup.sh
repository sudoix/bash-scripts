#!/bin/bash

# Constants
BACKUP_DIRECTORY="/data/gitlab/data/backups"
REMOTE_HOST="ubuntu@172.24.65.81" # chenge User@IP to your remote server user and IP
REMOTE_DIRECTORY="/home/ubuntu/backup"

echo "[$(date)] Script started."

# Find GitLab Docker container name
DOCKER_GITLAB_CONTAINER_NAME=$(docker ps --format "{{.Names}}\t{{.Image}}" | grep gitlab | cut -f1) # chenge gitlab-ce to your container name

if [ -z "$DOCKER_GITLAB_CONTAINER_NAME" ]; then
    echo "[$(date)] GitLab container not found. Exiting."
    exit 1
fi

echo "[$(date)] Found GitLab container: $DOCKER_GITLAB_CONTAINER_NAME"

# Backup
echo "[$(date)] Creating GitLab backup..."
docker exec "$DOCKER_GITLAB_CONTAINER_NAME" gitlab-backup create

if [ $? -ne 0 ]; then
    echo "[$(date)] Backup failed. Exiting."
    exit 1
fi

# Transfer
echo "[$(date)] Transferring backup to remote server..."
rsync -avz --progress --remove-source-files "$BACKUP_DIRECTORY/" "$REMOTE_HOST:$REMOTE_DIRECTORY"

if [ $? -ne 0 ]; then
    echo "[$(date)] Transfer failed. Exiting."
    exit 1
fi

# Cleanup
echo "[$(date)] Cleaning up local backup files..."
rm -rf "$BACKUP_DIRECTORY"/*

if [ $? -ne 0 ]; then
    echo "[$(date)] Cleanup failed."
    exit 1
fi

echo "[$(date)] Backup process completed successfully."




# docker exec `docker ps --format "{{.Names}}\t {{.Image}}" | grep gitlab-ce | cut -d' ' -f1` gitlab-backup create

# scp /data/gitlab/data/backups/* ubuntu@172.24.65.81:/home/ubuntu/backup/

# rm -rf /data/gitlab/data/backups/*
