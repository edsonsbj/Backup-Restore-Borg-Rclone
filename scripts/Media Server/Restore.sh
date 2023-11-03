#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; } 

## ---------------------------------- TESTS ------------------------------ #
# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

# -------------------------------FUNCTIONS----------------------------------------- #
# Obtaining file information and dates to be restored
check_restore() {

    # Start Rclone Mount    
    systemctl start borgbackup.service

    # Change to the root directory. This is critical because borg extract uses relative directory, so we must change to the root of the system to avoid errors or random directories during restoration.
    echo "Changing to the root directory..."
    cd /
    echo "pwd is $(pwd)"
    echo "location of the database backup file is " '/'
    
    if [ $? -eq 0 ]; then
        echo "Done"
    else
        echo "Failed to change to the root directory. Restoration failed."
        exit 1
    fi

    ARCHIVE_DATE=$1

    # Check if the restoration date is specified
    if [ -z "$ARCHIVE_DATE" ]
    then
        echo "Please specify the restoration date."
        exit 1
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
    echo "========== Restoring Media Server settings $( date )... =========="
    echo ""

    check_restore

    # Stop Media Server
    sudo systemctl stop $MediaserverService

    # Remove the current directory from Media Derver
    mv "$MediaserverConf" "$MediaserverConf.bk"

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME "$MediaserverConf"

    # Restore permissions
    chmod -R 755 $MediaserverConf
    chown -R $MediaserverUser:$MediaserverUser $MediaserverConf

    # Add the Media Server User to the www-data group to access Nextcloud folders
    sudo adduser $MediaserverUser www-data

    # Start Media Server
    sudo systemctl start $MediaserverService

    # Removing unnecessary files
    rm -rf "$MediaserverConf.bk"

    # Sleep for 3 hours before unmounting the drive
    sleep 10800

    # Stop Rclone Mount    
    systemctl stop borgbackup.service
}

# Call the restore function
restore