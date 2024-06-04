#!/bin/bash

# Exit when any command fails and enable debugging
set -Eeuo pipefail

# Get the directory where the script is located
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

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

## ---------------------------------- TESTS ------------------------------ #
# Check if the script is being executed by root or with sudo
if [ $EUID -ne 0 ]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

# -------------------------------FUNCTIONS----------------------------------------- #
BORG_OPTS="--verbose --filter AME --list --progress --stats --show-rc --compression lz4 --exclude-caches"

# Start Rclone Mount    
systemctl start borgbackup.service

# Maintenance mode functions
toggle_nextcloud_mode() {
    sudo -u www-data php "$NextcloudConfig/occ" maintenance:mode --"$1"
}

# Webserver control functions
toggle_webserver() {
    systemctl "$1" "$webserverServiceName"
}

# Mediaserver control functions
toggle_mediaserver() {
    systemctl "$1" "$MediaserverService"
}

# Mediaserver control functions
borg_patterns_file() {
    # Filters for Inclusion Exclusion Borg
    BorgFilters="./patterns.lst"

    # Create a file with the delete standards Borg Inclusion
    tee -a "$BorgFilters" <<EOF > /dev/null 2>&1
P sh
R /

# DO NOT LOOK IN THESE FOLDERS
! proc

# DIRECTORIES TO BE EXCLUDED FROM BACKUP  

# Media Server
- $MediaserverConf/Cache
- $MediaserverConf/cache
- $MediaserverConf/Crash Reports
- $MediaserverConf/Diagnostics
- $MediaserverConf/Logs
- $MediaserverConf/logs
- $MediaserverConf/transcoding-temp

# NEXTCLOUD
- $NextcloudDataDir/*/files_trashbin

# DIRECTORIES FOR BACKUP 

# Media Server Include
+ $MediaserverConf/

# NEXTCLOUD - SETTINGS
+ $NextcloudConfig/
+ $NextcloudDataDir/

# DO NOT INCLUDE ANY MORE FILES
- **
EOF
}

# Function to Prune Repository
prune() {
    info "Pruning repository"

    # Use the subcoming `prune` to keep 7 days, 4 per week and 6 per month
    # files of this machine.The prefix '{hostname}-' is very important for
    # limits PLA's operation to files in this machine and does not apply to
    # Files of other machines too:

    borg prune --list --progress --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6
}

# Function to backup Nextcloud settings
nextcloud_settings() {
    info "Backing up Nextcloud settings $(date)..."

    # Place the server in maintenance mode and stop the web server
    toggle_nextcloud_mode on
    toggle_webserver stop

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS ::'NextcloudConfigs-{now:%Y%m%d-%H%M}' $NextcloudConfig --exclude $NextcloudDataDir

    backup_exit=$?

    # Remove the database
    rm "$NextcloudConfig/nextclouddb.sql"

    # Starts the web server and disables maintenance mode
    toggle_webserver start
    toggle_nextcloud_mode off
}

# Function to backup Nextcloud DATA folder
nextcloud_data() {
    info "Backing up Nextcloud DATA folder $(date)..."

    # Enables the maintenance mode
    toggle_nextcloud_mode on

    # Backup
    borg create $BORG_OPTS ::'NextcloudData-{now:%Y%m%d-%H%M}' $NextcloudDataDir --exclude "$NextcloudDataDir/*/files_trashbin"

    # Disables the maintenance mode
    toggle_nextcloud_mode off
}

# Function to perform a complete Nextcloud backup
nextcloud_complete() {
    info "Backing up Nextcloud $(date)..."
    
    # Place the server in maintenance mode and stop the web server
    toggle_nextcloud_mode on
    toggle_webserver stop

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS ::'NextcloudFull-{now:%Y%m%d-%H%M}' $NextcloudConfig $NextcloudDataDir --exclude "$NextcloudDataDir/*/files_trashbin"

    # Remove the database
    rm "$NextcloudConfig/nextclouddb.sql"

    # Starts the web server and disables maintenance mode
    toggle_webserver start
    toggle_nextcloud_mode of
}

# Function to backup Nextcloud and Media Server settings
nextcloud_mediaserver_settings() {
    info "Backing up Nextcloud and Media Server settings $(date)..."

    # Create the Patterns file
    borg_patterns_file

    # Place the server in maintenance mode and stop the web server and media server
    toggle_nextcloud_mode on
    toggle_webserver stop
    toggle_mediaserver stop
    
   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS --patterns-from "$BorgFilters" ::'SettingsServer-{now:%Y%m%d-%H%M}'

    # Remove unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm "$BorgFilters"

    # Starts the web server and disables maintenance mode
    toggle_webserver start
    toggle_nextcloud_mode off
    toggle_mediaserver start
}

# Function to backup Nextcloud and Media Server settings
nextcloud_mediaserver_complete() {
    info "Backing up Nextcloud and Media Server settings $(date)..."

    # Create the Patterns file
    borg_patterns_file

    # Place the server in maintenance mode and stop the web server and media server
    toggle_nextcloud_mode on
    toggle_webserver stop
    toggle_mediaserver stop

   	# Export the database.
	mysqldump --quick -n --host=localhost $NextcloudDatabase --user=$DBUser --password=$DBPassword > "$NextcloudConfig/nextclouddb.sql"

    # Backup
    borg create $BORG_OPTS --patterns-from "$BorgFilters" ::'SettingsServer-{now:%Y%m%d-%H%M}'

    # Remove unnecessary files
    rm "$NextcloudConfig/nextclouddb.sql"
    rm "$BorgFilters"

    # Starts the web server and disables maintenance mode
    toggle_webserver start
    toggle_nextcloud_mode off
    toggle_mediaserver start
}

# Execute the corresponding backup option
run_backup() {
    local option="$1"
    case $option in
        1) nextcloud_settings ;;
        2) nextcloud_data ;;
        3) nextcloud_complete ;;
        4) nextcloud_mediaserver_settings ;;
        5) nextcloud_mediaserver_complete ;;
        *) echo "Invalid option!" && return 1 ;;
    esac
    prune
}

# Check if an option was passed as an argument
if [[ -n ${1:-} ]]; then
    run_backup "$1"
else
    # Display the menu to choose the Backup option
    echo "Choose a Backup option:"
    echo "1. Backup Nextcloud configurations and database."
    echo "2. Backup only the Nextcloud data folder. Useful if the folder is stored elsewhere."
    echo "3. Backup Nextcloud configurations, database, and data folder."
    echo "4. Backup Nextcloud and Media Server Settings."
    echo "5. Backup Nextcloud settings, database and data folder, as well as Media Server settings."
    echo "6. To go out."

    # Read the option entered by the user
    read -r option
    run_backup "$option"
fi

    # Sleep for 3 hours before unmounting the drive
    sleep 5400

    # Stop Rclone Mount    
    systemctl stop borgbackup.service