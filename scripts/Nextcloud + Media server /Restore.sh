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

# Function to WebServer Stop Start
stop_mediaserver() {
    # Stop Media Server
    systemctl stop "$MediaserverService"
}

start_mediaserver() {
    # Start Media Server
	systemctl start $MediaserverService
}

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

# Function to restore Nextcloud settings
nextcloud_settings() {
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    check_restore

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
    
    start_webserver

    nextcloud_disable
}

# Function to restore Nextcloud DATA folder
nextcloud_data() {
    echo "========== Restoring Nextcloud DATA folder $( date )...=========="
    echo ""

    check_restore

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

    check_restore

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

    start_webserver

    nextcloud_disable
}

# Function to restore Nextcloud and Media Server settings
nextcloud_mediaserver_settings() {
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    check_restore

    nextcloud_enable

    stop_webserver

    stop_mediaserver

    # Removing old versions 
    mv $NextcloudConfig '$NextcloudConfig.old/'
    mv "$MediaserverConf" "$MediaserverConf.old/"

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudConfig "$MediaserverConf"

    # Restore the database
    mysql -u --host=localhost --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql" >> $RESTLOGFILE_PATH

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig
    chmod -R 755 $MediaserverConf
    chown -R $MediaserverUser:$MediaserverUser $MediaserverConf

    # Add the Media Server User to the www-data group to access Nextcloud folders
    sudo adduser $MediaserverUser www-data

    start_webserver

    start_mediaserver

    nextcloud_disable

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
}

# Function to perform a complete Nextcloud and Media Server Settings restore
nextcloud_mediaserver_complete() {
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    check_restore

    nextcloud_enable

    stop_webserver

    stop_mediaserver

    # Removing old versions 
    mv $NextcloudConfig '$NextcloudConfig.old/'
    mv "$MediaserverConf" "$MediaserverConf.old/"

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME "$NextcloudConfig" "$NextcloudDataDir" "$MediaserverConf"

    # Restore the database
    mysql -u --host=localhost --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql" >> $RESTLOGFILE_PATH

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig
    chmod -R 755 $MediaserverConf
    chown -R $MediaserverUser:$MediaserverUser $MediaserverConf

    # Add the Media Server User to the www-data group to access Nextcloud folders
    sudo adduser $MediaserverUser www-data

    start_webserver

    start_mediaserver

    nextcloud_disable

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"   
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
        4)
            nextcloud_mediaserver_settings
            ;;
        5)
            nextcloud_mediaserver_complete
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
    echo "4. Restore Nextcloud and Media Server Settings."
    echo "5. Restore Nextcloud settings, database and data folder, as well as Media Server settings."
    echo "6. To go out."

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
        4)
            nextcloud_mediaserver_settings
            ;;
        5)
            nextcloud_mediaserver_complete
            ;;             
        6)
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