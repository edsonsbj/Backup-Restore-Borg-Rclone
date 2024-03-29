#!/bin/bash

# Make sure the script exits when any command fails
set -Eeuo pipefail

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
CONFIG="$SCRIPT_DIR/BackupRestore.conf"

# Check if config file exists
if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Configuration file $CONFIG cannot be found!"
    echo "Please make sure that a configuration file '$CONFIG' is present in the main directory of the scripts."
    echo "This file can be created automatically using the setup.sh script."
    exit 1
fi

source "$CONFIG"

ARCHIVE_DATE=${1:-""}

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; } 

# Start Rclone Mount    
systemctl start borgbackup.service

## ---------------------------------- TESTS ------------------------------ #
# Check if the script is being executed by root or with sudo
if [ $EUID -ne 0 ]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

# Change to the root directory, and exit with an error message if it fails
if cd /; then
    echo "Changed to the root directory ($(pwd))"
    echo "Location of the database backup file is /"
else
    echo "Failed to change to the root directory. Restoration failed."
    exit 1
fi

# -------------------------------FUNCTIONS----------------------------------------- #
# Obtaining file information and dates to be restored
check_restore() {
    # Check if the restoration date is specified
    if [ -z "$ARCHIVE_DATE" ]
    then        
        read -p "Enter the restoration date (YYYY-MM-DD): " ARCHIVE_DATE
    if [ -z "$ARCHIVE_DATE" ]
    then
        echo "No date provided. Going off script."
        exit 1
    fi
 fi

    # Find the backup file name corresponding to the specified date
    ARCHIVE_NAME=$(borg list $BORG_REPO | grep $ARCHIVE_DATE | awk '{print $1}')

    # Check if the backup file is found
    if [ -z "$ARCHIVE_NAME" ]
    then
        echo "Could not find a backup file for the specified date: $ARCHIVE_DATE"
        exit 1
    fi

}

# Function to Restore 
Restore() {
    check_restore
    
    echo "========== Restoring settings $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME "$SourceDir"

    # Sleep for 3 hours before unmounting the drive
    sleep 10800

    # Stop Rclone Mount    
    systemctl stop borgbackup.service
}

# Call the restore function
Restore $1