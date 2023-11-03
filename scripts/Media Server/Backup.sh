#!/bin/bash

CONFIG="$(dirname "${BASH_SOURCE[0]}")/BackupRestore.conf"
. $CONFIG

# Create a log file to record command outputs
touch "$LogFile"
exec > >(tee -a "$LogFile")
exec 2>&1

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

## ---------------------------------- TESTS ------------------------------ #

# Check if the script is being executed by root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "========== This script needs to be executed as root or with sudo. ==========" 
   exit 1
fi

## -------------------------- MAIN SCRIPT -------------------------- #
# Function to backup
backup() {
    BORG_OPTS="--verbose --filter AME --list --progress --stats --show-rc --compression lz4 --exclude-caches"

    # Filters for Inclusion Exclusion Borg
    BorgFilters="./patterns.lst"

    # Create a file with the delete standards Borg Inclusion
    tee -a "$BorgFilters" <<EOF
P sh
R /

# DO NOT LOOK IN THESE FOLDERS
! proc

# DIRECTORIES TO BE EXCLUDED FROM BACKUP  
- $MediaserverConf/Cache
- $MediaserverConf/cache
- $MediaserverConf/Crash Reports
- $MediaserverConf/Diagnostics
- $MediaserverConf/Logs
- $MediaserverConf/logs
- $MediaserverConf/transcoding-temp

# DIRECTORIES FOR BACKUP 
+ $MediaserverConf/

# DO NOT INCLUDE ANY MORE FILES
- **
EOF

    echo "========== Backing up $( date )... =========="
    echo ""
    
    # Start Rclone Mount    
    systemctl start borgbackup.service

    # Stop Media Server
    systemctl stop "$MediaserverService"

    # Backup
    borg create $BORG_OPTS patternsFrom "$BorgFilters" ::'MediaServer-{now:%Y%m%d-%H%M}' "$MediaserverConf"

    backup_exit=$?

    # Remove unnecessary files
    rm "$BorgFilters"

    # Start Media Server
    systemctl start "$MediaserverService"

    info "Pruning repository"

    # Use the subcoming `prune` to keep 7 days, 4 per week and 6 per month
    # files of this machine.The prefix '{hostname}-' is very important for
    # limits PLA's operation to files in this machine and does not apply to
    # Files of other machines too:

    borg prune --list --progress --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6

    prune_exit=$? 

    # Sleep for 3 hours before unmounting the drive
    sleep 10800

    # Stop Rclone Mount    
    systemctl stop borgbackup.service
}

# Call the backup function
backup

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a
fi