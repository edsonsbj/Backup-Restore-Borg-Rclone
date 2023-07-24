#!/bin/bash

CONFIG="/path/to/.conf"
. $CONFIG

# Some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

#
# Check if the Script is run by root
#
if [ "$(id -u)" != "0" ]
then
        errorecho "ERROR: This script must be run as root!"
        exit 1
fi

#
# Uncomment the following lines if it is necessary to restore files or folders from external storage such as pendrives and external HDs

# DO NOT CHANGE
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1"

# Is the Device Mounted?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
  # If not, mount on $MOUNTDIR
#  echo " Device not mounted. Mount $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
#  # If so, grep the mount point and change the $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Are there write and record permissions?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " No write permissions " >> $LOGFILE_PATH
#  exit 1
# }

info "Restoration Started" 2>&1 | tee -a $RESTLOGFILE_PATH

# Change to the root directory. This is critical because borg extract uses relative directory so we must change to the system root so that restoration occurs without errors or in random directories.

echo "Changing to the root directory..."
cd /
echo "pwd is $(pwd)"
echo "backup file location db is " '/'

if [ $? -eq 0 ]; then
    echo "Done"
else
    echo "failed to change to root directory. Restoration failed"
    exit 1
fi

# Check if the restore date was specified
if [ -z "$ARCHIVE_DATE" ]
then
    echo "Please specify the restore date."
    exit 1
fi

# Check if the restore date and file to be restored were specified
if [ -z "$ARCHIVE_DATE" ] || [ -z "$FILE_TO_RESTORE" ]
then
    echo "Please specify the restore date and file to be restored as first and second arguments, respectively."
    exit 1
fi

# Find the name of the backup file corresponding to the specified date
ARCHIVE_NAME=$(borg list $REPOSITORY | grep $ARCHIVE_DATE | awk '{print $1}')

# Check if the backup file was found
if [ -z "$ARCHIVE_NAME" ]
then
    echo "Could not find a backup file for the specified date: $ARCHIVE_DATE"
    exit 1
fi

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; } 

# Create necessary folders

mkdir /mnt/rclone/Borg /var/log/Rclone /var/log/Borg

# Mount Rclone

sudo systemctl start Backup.service

# Restore backup
#
echo "Restoring backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $FILE_TO_RESTORE >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $RESTLOGFILE_PATH"
