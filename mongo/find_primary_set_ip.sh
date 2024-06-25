#!/bin/bash

##########################################################################################
# Script Name: dynamic_ip_manager.sh
# Description:
#    This script automatically manages the network IP settings for a server based on its role
#    within a MongoDB cluster. It periodically checks if the current server is the primary node
#    of the MongoDB replica set. If so, it assigns a specified IP address to a designated network
#    interface. If the server is not the primary node, or if it loses the primary status, the
#    script removes the IP address from the interface. The script logs all actions and maintains
#    the log file to include only the most recent 100 entries.
#
# Prerequisites:
#    - MongoDB running locally or within the same network.
#    - Administrative privileges to modify network interface settings.
#    - 'mongosh' for MongoDB commands and network utilities (ip, hostname) installed.
#
# Usage: sudo ./dynamic_ip_manager.sh
# Parameters:
#    No external parameters are required; all necessary settings (MongoDB credentials, target IP, etc.)
#    are configured within the script.
#
# Author: Sudoix
# Date: December 26, 2023
# Version: 1.0
##########################################################################################

# Configuration Variables
MONGO_USER="root"
MONGO_PASSWORD="123456"
MONGO_HOST="localhost"
MONGO_AUTH_DB="admin"
TARGET_IP="172.16.100.100"
NET_INTERFACE="eth1"
LOG_FILE="/var/log/ip_setter.log"

# Function to log messages
log_message() {
    echo "$(date) - $1" >> $LOG_FILE
    # Keep only the last 100 lines in the log file
    tail -n 100 $LOG_FILE > $LOG_FILE.tmp
    mv $LOG_FILE.tmp $LOG_FILE
}

while true; do
    # Check MongoDB port and retrieve primary node's address if port is open
    PRIMARY_IP=$(nc -z $MONGO_HOST 27017 && mongosh -u $MONGO_USER -p $MONGO_PASSWORD --host $MONGO_HOST --authenticationDatabase $MONGO_AUTH_DB --eval "printjson(rs.isMaster().primary)" | tail -n -1 | awk -F':' '{print $1}' 2>>$LOG_FILE)

    # Check if PRIMARY_IP is empty (which means MongoDB port is down or node is not primary)
    if [ -z "$PRIMARY_IP" ]; then
        log_message "MongoDB port 27017 is down or this node is not primary."
        
        # If IP is set, remove it
        if ip addr show $NET_INTERFACE | grep $TARGET_IP > /dev/null; then
            ip addr del $TARGET_IP/24 dev $NET_INTERFACE
            log_message "IP $TARGET_IP has been removed from $NET_INTERFACE."
        else
            log_message "No changes made; IP $TARGET_IP was not set on $NET_INTERFACE."
        fi

        sleep 5
        continue
    fi

    log_message "Primary IP: $PRIMARY_IP"

    # Obtain the server's main IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')
    log_message "Server IP: $SERVER_IP"

    # Check if the server IP is the same as the primary IP and set the specified IP if it matches
    if [ "$SERVER_IP" == "$PRIMARY_IP" ]; then
        if ip link show $NET_INTERFACE > /dev/null 2>&1; then
            # Check if IP is already set
            if ! ip addr show $NET_INTERFACE | grep $TARGET_IP > /dev/null; then
                ip addr add $TARGET_IP/24 dev $NET_INTERFACE
                log_message "IP $TARGET_IP has been set on $NET_INTERFACE."
            else
                log_message "$TARGET_IP is already set on $NET_INTERFACE."
            fi
        else
            log_message "Network interface $NET_INTERFACE not found."
        fi
    else
        # If not primary, and if IP is set, remove it
        if ip addr show $NET_INTERFACE | grep $TARGET_IP > /dev/null; then
            ip addr del $TARGET_IP/24 dev $NET_INTERFACE
            log_message "IP $TARGET_IP has been removed from $NET_INTERFACE since this node is no longer primary."
        else
            log_message "No changes made; IP $TARGET_IP was not set on $NET_INTERFACE or this node is not primary."
        fi
    fi

    # Sleep for 10 seconds before the next loop iteration
    sleep 10
done
