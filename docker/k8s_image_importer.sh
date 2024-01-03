#!/bin/bash

##########################################################################################
# Script Name: k8s_image_importer.sh
# Description:
#    This script automates the process of downloading and importing Kubernetes images 
#    from a specified URL. It downloads .tar files and imports them using the 'ctr' command.
#    The script includes error handling, skips redundant downloads, cleans up 
#    downloaded files after successful import, and logs the process.
#
# Prerequisites:
#    - 'wget' installed for fetching file lists and downloading files.
#    - 'sudo' privileges for the 'ctr' command to import images.
#    - Internet connectivity to access the specified URL.
#    - Adequate disk space for temporary storage of downloaded files.
#
# Usage: ./k8s_image_importer.sh
#
# Author: Sudoix
# Date: January 2, 2024
# Version: 1.0
##########################################################################################

# Function to check if a program is installed
check_and_install() {
    if ! command -v $1 &> /dev/null
    then
        echo "$1 could not be found, attempting to install."
        sudo apt-get update && sudo apt-get install -y $1
    else
        echo "$1 is already installed."
    fi
}

# Check for 'wget', install if not present
check_and_install wget

# URL of the directory containing files
url="https://image.sudoix.ir/k8s_1_28_5/"

# Log file for tracking
log_file="import_images.log"
echo "Starting the process" > "$log_file"

# Get the list of files from the URL
file_list=$(wget -q -O - $url | grep -oP '(?<=href=")[^"]*.tar')

# Iterate over each file in the list
for file in $file_list; do
    echo "Processing $file..."

    # Skip download if file already exists
    if [ -f "$file" ]; then
        echo "$file already exists, skipping download." | tee -a "$log_file"
    else
        echo "Downloading $file..."
        if wget -q "${url}${file}"; then
            echo "Downloaded $file successfully." | tee -a "$log_file"
        else
            echo "Failed to download $file." | tee -a "$log_file"
            continue
        fi
    fi

    # Importing the image
    echo "Importing $file..."
    if sudo ctr -n=k8s.io image import "$file"; then
        echo "Imported $file successfully." | tee -a "$log_file"
        rm "$file" # Remove the file after successful import
    else
        echo "Failed to import $file." | tee -a "$log_file"
    fi
done

echo "All files processed." | tee -a "$log_file"
