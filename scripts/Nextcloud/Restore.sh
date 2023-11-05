#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

ARCHIVE_DATE=$1

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

# -------------------------------FUNCTIONS----------------------------------------- #
# Function to Nextcloud Maintenance Mode
nextcloud_enable() {
    # Enabling Maintenance Mode
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --on
}

nextcloud_disable() {
    # Disabling Nextcloud Maintenance Mode
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --off
}

# Function to WebServer Stop Start
stop_webserver() {
    # Stop Web Server
	systemctl stop $webserverServiceName
}

start_webserver() {
    # Stop Web Server
	systemctl start $webserverServiceName
}

# Function to restore Nextcloud settings
nextcloud_settings() {
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    nextcloud_enable

    stop_webserver

    # Removing old versions 
    mv $NextcloudConfig '$NextcloudConfig.old/'

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudConfig

    # Restore the database
    mysql -u --host=localhost --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql" >> $RESTLOGFILE_PATH

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"

    nextcloud_disable

    start_webserver    
}

# Function to restore Nextcloud DATA folder
nextcloud_data() {
    echo "========== Restoring Nextcloud DATA folder $( date )...=========="
    echo ""

    nextcloud_enable

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudDataDir

    # Restore permissions
    chmod -R 770 $NextcloudDataDir 
    chown -R www-data:www-data $NextcloudDataDir

    nextcloud_disable
}

# Function to restore Nextcloud
nextcloud_complete() {
    echo "========== Restoring Nextcloud $( date )... =========="
    echo ""

    nextcloud_enable

    stop_webserver

    # Removing old versions 
    mv $NextcloudConfig '$NextcloudConfig.old/'

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudConfig $NextcloudDataDir

    # Restore the database
    mysql -u --host=localhost --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql" >> $RESTLOGFILE_PATH

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig
    chmod -R 770 $NextcloudDataDir 
    chown -R www-data:www-data $NextcloudDataDir

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    
    nextcloud_disable

    start_webserver
}

# Check if an option was passed as an argument
if [[ ! -z $1 ]]; then
    # Execute the corresponding Restore option
    case $1 in
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