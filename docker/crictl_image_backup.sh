#!/bin/bash

##########################################################################################
# Script Name: crictl_image_backup.sh
# Description:
#    Automates the backup of container images managed by a CRI-compatible runtime
#    (like containerd) in a specified directory. It creates timestamped backups for
#    container images, pulls the latest versions, and saves them as .tar files with
#    their names and tags using 'ctr -n=k8s.io image export' command. 
#    Duplicate images are skipped to save space.
#
# Prerequisites:
#    - A CRI-compatible container runtime (like containerd) installed and configured.
#    - 'crictl' and 'ctr' commands available.
#
# Usage: ./crictl_image_backup.sh
#
# Author: Sudoix
# Date: January 1, 2024
# Version: 1.3
##########################################################################################

# Check if the 'crictl' and 'ctr' commands are available
if ! command -v crictl &> /dev/null || ! command -v ctr &> /dev/null; then
    echo "Error: 'crictl' and/or 'ctr' commands not found. Please install a CRI-compatible container runtime and try again."
    exit 1
fi

# Check if 'jq' is installed
if ! command -v jq &> /dev/null; then
    sudo apt update && sudo apt install jq -y
fi

# Constants
LISTS_FILE="lists"
OUTPUT_DIR="cri_images"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Use 'crictl images' to list images and extract their names and tags
crictl images --output json | jq -r '.images[] | "\(.repoTags[])"' > "$LISTS_FILE"

# Check if the file was created successfully
if [ -f "$LISTS_FILE" ]; then
    echo "List of container images with tags saved in '$LISTS_FILE'"
else
    echo "Error: Failed to create the list of container images with tags."
    exit 1
fi

# Read 'lists' file line by line and process each image with tag
while read -r imageWithTag; do
    # Replace colons and slashes with underscores to avoid file name issues
    safeImageName=$(echo "$imageWithTag" | sed 's/[:/]/_/g')

    # Check if the image has already been pulled and saved
    if [ ! -f "$OUTPUT_DIR/${safeImageName}.tar" ]; then
        echo "Pulling container image: $imageWithTag"
        crictl pull "$imageWithTag"
        echo "Exporting container image '$imageWithTag' as '${safeImageName}.tar'"
        ctr -n=k8s.io image export "$OUTPUT_DIR/${safeImageName}.tar" "$imageWithTag"
    else
        echo "Container image '$imageWithTag' already exists as '${safeImageName}.tar'. Skipping."
    fi
done < "$LISTS_FILE"

echo "All container images processed."
