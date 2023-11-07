#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

ARCHIVE_DATE=$2

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
if [[ $EUID -ne 0 ]]; then
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

# Function to restore Nextcloud settings
nextcloud_settings() {
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    check_restore

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudSnapConfig

    # Enable Midias Removevel
    sudo snap connect nextcloud:removable-media

    # Import the settings and database
    sudo nextcloud.import -abc $NextcloudSnapConfig

    # Removing unnecessary files
    rm -rf $NextcloudSnapConfig 
}

# Function to restore Nextcloud DATA folder
nextcloud_data() {

    check_restore

    # Enabling Maintenance Mode
    echo "============ Enabling Maintenance Mode... ============"
	sudo nextcloud.occ maintenance:mode --on
    echo ""

    echo "========== Restoring Nextcloud DATA folder $( date )...=========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudDataDir

    # Restore permissions
    chmod -R 770 $NextcloudDataDir 
    chown -R www-data:www-data $NextcloudDataDir

    # Disabling Maintenance Mode
    echo "============ Disabling Maintenance Mode... ============"
	sudo nextcloud.occ maintenance:mode --off
    echo ""
}

# Function to restore Nextcloud
nextcloud_complete() {

    check_restore

    # Enabling Maintenance Mode
    echo "============ Enabling Maintenance Mode... ============"
	sudo nextcloud.occ maintenance:mode --on
    echo ""

    # Enable Midias Removevel
    sudo snap connect nextcloud:removable-media

    echo "========== Restoring Nextcloud $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudSnapConfig $NextcloudDataDir

    # Import the settings and database
    sudo nextcloud.import -abc $NextcloudSnapConfig

    # Removing unnecessary files
    rm -rf $NextcloudSnapConfig 

    # Restore permissions
    chmod -R 770 $NextcloudDataDir 
    chown -R root:root $NextcloudDataDir

    # Disabling Maintenance Mode
    echo "============ Disabling Maintenance Mode... ============"
	sudo nextcloud.occ maintenance:mode --off
    echo ""
}

# Check if an option was passed as an argument
if [[ ! -z $1 ]]; then
    # Execute the corresponding Restore option
    case $1 in
        1)
            nextcloud_settings $2
            ;;
        2)
            nextcloud_data $2
            ;;
        3)
            nextcloud_complete $2
            ;;
        *)
            echo "Invalid option!"
            ;;
    esac
else
    # Display the menu to choose the Restore option
    echo "Choose a Restore option:"
    echo "1. Restore Nextcloud configurations and database."
    echo "2. Restore only the Nextcloud data folder. Useful if the folder is stored elsewhere."
    echo "3. Restore Nextcloud configurations, database, and data folder."
    echo "4. To go out."

    # Read the option entered by the user
    read option

    # Execute the corresponding Restore option
    case $option in
        1)
            nextcloud_settings
            ;;
        2)
            nextcloud_data
            ;;
        3)
            nextcloud_complete
            ;;
        *)
            echo "Invalid option!"
            ;;
        4)
            echo "Leaving the script."
            exit 0
            ;;            
        *)
            echo "Invalid option!"
            ;;
    esac
fi

    # Sleep for 3 hours before unmounting the drive
    sleep 10800

    # Stop Rclone Mount    
    systemctl stop borgbackup.service