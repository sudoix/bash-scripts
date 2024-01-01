#!/bin/bash

##########################################################################################
# Script Name: docker_image_backup.sh
# Description:
#    Automates the backup of Docker images in a specified directory.
#    It creates timestamped backups for Docker images, pulls the latest versions,
#    and saves them as .tar files. Duplicate images are skipped to save space.
#
# Prerequisites:
#    - Docker installed and configured.
#    - 'docker image ls' command available.
#
# Usage: ./docker_image_backup.sh
#
# Author: Sudoix
# Date: January 1, 2024
# Version: 1.0
##########################################################################################


# Check if the 'docker' command is available
if ! command -v docker &> /dev/null; then
    echo "Error: 'docker' command not found. Please install Docker and try again."
    exit 1
fi

# Constants
LISTS_FILE="lists"
OUTPUT_DIR="docker_images"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Use 'docker image ls' to list images and extract their repository and tag
docker image ls --format '{{.Repository}}:{{.Tag}}' > "$LISTS_FILE"

# Check if the file was created successfully
if [ -f "$LISTS_FILE" ]; then
    echo "List of Docker images saved in '$LISTS_FILE'"
else
    echo "Error: Failed to create the list of Docker images."
    exit 1
fi

# Read 'lists' file line by line and process each image
while read -r i; do
    # Extract the image name (last part after '/') without leading spaces
    image=$(echo "$i" | awk -F/ '{latest = $NF; sub(/^[ \t]+/, "", latest); print latest}')
    
    # Check if the image has already been pulled and saved
    if [ ! -f "$OUTPUT_DIR/${image}.tar" ]; then
        echo "Pulling Docker image: $i"
        docker pull "$i"
        echo "Saving Docker image '$i' as '${image}.tar'"
        docker save -o "$OUTPUT_DIR/${image}.tar" "$i"
    else
        echo "Docker image '$i' already exists as '${image}.tar'. Skipping."
    fi
done < "$LISTS_FILE"

echo "All Docker images processed and saved in '$OUTPUT_DIR'"
