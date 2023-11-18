#!/bin/bash

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

ARCHIVE_DATE=${2:-""}

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

# Function for obtaining information from NextCloud
info() {
    # Obtaining Information for Restoration 
    RestNextcloudDataDir=$(grep -oP "(?<='datadirectory' => ').*?(?=',)" "$NextcloudConfig/config/config.php")
    RestDatabaseSystem=$(grep -oP "(?<='dbtype' => ').*?(?=',)" "$NextcloudConfig/config/config.php")
    RestNextcloudDatabase=$(grep -oP "(?<='dbname' => ').*?(?=',)" "$NextcloudConfig/config/config.php")
    RestDBUser=$(grep -oP "(?<='dbuser' => ').*?(?=',)" "$NextcloudConfig/config/config.php")
    RestDBPassword=$(grep -oP "(?<='dbpassword' => ').*?(?=',)" "$NextcloudConfig/config/config.php")

    sed -i "/^NextcloudDataDir=/c\NextcloudDataDir='$RestNextcloudDataDir'" "$CONFIG"
    sed -i "/^DatabaseSystem=/c\DatabaseSystem='$RestDatabaseSystem'" "$CONFIG"
    sed -i "/^NextcloudDatabase=/c\NextcloudDatabase='$RestNextcloudDatabase'" "$CONFIG"
    sed -i "/^DBUser=/c\DBUser='$RestDBUser'" "$CONFIG"
    sed -i "/^DBPassword=/c\DBPassword='$RestDBPassword'" "$CONFIG"

    # Recharging the variables
    source "$CONFIG"

}

# Function to Nextcloud Maintenance Mode
nextcloud_enable() {
    # Enabling Maintenance Mode
    echo "============ Enabling Maintenance Mode... ============"
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --on
    echo ""
}

nextcloud_disable() {
    # Disabling Nextcloud Maintenance Mode
    echo "============ Disabling Maintenance Mode... ============"
	sudo -u www-data php $NextcloudConfig/occ maintenance:mode --off
    echo ""
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

# Function to restore Nextcloud settings
nextcloud_settings() {

    check_restore

    stop_webserver

    # Removing old versions 
    mv $NextcloudConfig "$NextcloudConfig.old/"
    
    echo "========== Restoring Nextcloud settings $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudConfig

    info

    # Remove the Old Database and NextCloud User
    mysql -e "DROP DATABASE $NextcloudDatabase;"
    mysql -e "ALTER USER '$DBUser'@'localhost' IDENTIFIED BY '$DBPassword';"

    # Restore the database
    mysql --user=$DBUser --password=$DBPassword -e "CREATE DATABASE $NextcloudDatabase CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"    
    mysql --user=$DBUser --password=$DBPassword $NextcloudDatabase < "$NextcloudConfig/nextclouddb.sql"

    # Restore permissions
    chmod -R 755 $NextcloudConfig
    chown -R www-data:www-data $NextcloudConfig

    start_webserver    

    # Removing unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm -rf "$NextcloudConfig.old/"
}

# Function to restore Nextcloud DATA folder
nextcloud_data() {

    check_restore

    nextcloud_enable

    echo "========== Restoring Nextcloud DATA folder $( date )...=========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NextcloudDataDir

    # Restore permissions
    chmod -R 770 $NextcloudDataDir 
    chown -R www-data:www-data $NextcloudDataDir

    nextcloud_disable
}

# Function to restore Nextcloud and Media Server settings
mediaserver_settings() {

    check_restore

    stop_mediaserver

    # Remove the current folder
    mv "$MediaserverConf" "$MediaserverConf.old/"

    echo "========== Restoring Nextcloud Settings and Media Server Settings $( date )... =========="
    echo ""

    # Extract Files
    borg extract -v --list $BORG_REPO::$ARCHIVE_NAME "$MediaserverConf"

    # Restore permissions
    chmod -R 755 $MediaserverConf
    chown -R $MediaserverUser:$MediaserverUser $MediaserverConf

    # Add the Media Server User to the www-data group to access Nextcloud folders
    sudo adduser $MediaserverUser www-data

    start_mediaserver

    rm -rf "$MediaserverConf.old/"
}

# Check if an option was passed as an argument
if [[ ! -z ${1:-""} ]]; then
    # Execute the corresponding Restore option
    case $1 in
        1)
            nextcloud_settings $2
            ;;
        2)
            nextcloud_data $2
            ;;
        3)
            nextcloud_settings $2
            nextcloud_data $2
            ;;  
        4)
            nextcloud_settings $2
            mediaserver_settings $2
            ;;
        5)
            nextcloud_settings $2
            nextcloud_data $2
            mediaserver_settings $2
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
            nextcloud_settings
            nextcloud_data
            ;;  
        4)
            nextcloud_settings
            mediaserver_settings
            ;;
        5)
            nextcloud_settings
            nextcloud_data
            mediaserver_settings
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