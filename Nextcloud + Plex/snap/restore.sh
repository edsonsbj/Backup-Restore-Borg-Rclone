#!/bin/bash

CONFIG="/path/to/.conf"
. $CONFIG

# Some helpers and error handling:
info() { printf "\n%s %s\n\n" "$(date)" "$*" >&2; }
trap 'echo $(date) Backup interrupted >&2; exit 2' INT TERM

#
# Check if the script is executed by root
#
if [ "$(id -u)" != "0" ]
then
        echo "ERROR: This script must be executed as root!"
        exit 1
fi

#
# Uncomment the following lines if you need to restore files or folders from external storage devices such as USB drives and external HDDs

# DO NOT MODIFY
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1"

# Is the device mounted?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
  # If not, mount it at $MOUNTDIR
#  echo "Device not mounted. Mount $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
#  # If yes, grep the mount point and change $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Are there write and execute permissions?
# [ ! -w "$MOUNTDIR" ] && {
#  echo "Does not have write permissions " >> $LOGFILE_PATH
#  exit 1
# }

info "Restoration Started" 2>&1 | tee -a $RESTLOGFILE_PATH

# Change to the root directory. This is critical as borg extract uses a relative directory, so we need to change to the root of the system to ensure the restoration occurs without errors or in random directories.

echo "Changing to the root directory..."
cd /
echo "pwd is $(pwd)"
echo "location of the backup db file is " '/'

if [ $? -eq 0 ]; then
    echo "Done"
else
    echo "Failed to change to the root directory. Restoration failed."
    exit 1
fi

# Check if the restoration date has been specified
if [ -z "$ARCHIVE_DATE" ]
then
    echo "Please specify the restoration date."
    exit 1
fi

# Find the backup file name corresponding to the specified date
ARCHIVE_NAME=$(borg list $BORG_REPO | grep $ARCHIVE_DATE | awk '{print $1}')

# Check if the backup file was found
if [ -z "$ARCHIVE_NAME" ]
then
    echo "Could not find a backup file for the specified date: $ARCHIVE_DATE"
    exit 1
fi

# Error message function
errorecho() { cat <<< "$@" 1>&2; } 

# Create the necessary folders

mkdir /mnt/rclone/Borg /var/log/Rclone /var/log/Borg

# Mount Rclone

sudo systemctl start Backup.service

# Check if the backup file exists
if [ -z "RESTORE_FILE" ]; then
    echo "No backup file found"
    exit 1
fi

# Activate Maintenance Mode

echo
sudo nextcloud.occ maintenance:mode --on >> $LOGFILE_PATH
echo 

# Restore Nextcloud settings 
# 
echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

sudo nextcloud.import -abc $RESTORE_FILE >> $RESTLOGFILE_PATH

echo
echo "DONE!"

# Restore the ./data Nextcloud folder.
# Useful if the ./data folder is outside /var/www/nextcloud; otherwise, it is recommended to comment out the line below as your server will already be restored with the above command. 
# 
echo "Restoring ./data folder backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore permissions 

chmod -R 770 $NEXTCLOUD_DATA 
chown -R root:root $NEXTCLOUD_DATA
chown -R root:root $NEXTCLOUD_CONF

# For NTFS and FAT32 file systems, among others that do not accept permissions, it is advisable to add an entry in your /etc/fstab file. Uncomment the line below and change the UUID /mnt/YOURHD and the ntfs-3g field.
# To find the UUID of your partition or HDD, execute the command sudo blkid. 

#cp /etc/fstab /etc/fstab.bk
#sudo cat <<EOF >>/etc/fstab
#UUID=089342544239044F /mnt/YOURHD ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
#EOF

echo
echo "DONE!"

# Deactivate Maintenance Mode for Nextcloud

echo
sudo nextcloud.occ maintenance:mode --off >> $LOGFILE_PATH
echo

# Restore Plex Media Server settings

echo "Restoring Plex backup" >> $RESTLOGFILE_PATH

# Stop Plex

sudo systemctl stop plexmediaserver

# Stop Plex (snap)

#sudo snap stop plexmediaserver

# Remove the current Plex folder

rm -rf $PLEX_CONF

# Extract Files

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $PLEX_CONF >> $RESTLOGFILE_PATH 2>&1

# Restore permissions

chmod -R 755 $PLEX_CONF
chown -R plex:plex $PLEX_CONF

# Restore permissions (snap)

#chmod -R 755 $PLEX_CONF
#chown -R root:root $PLEX_CONF

# Add the Plex User to the www-data group to access Nextcloud folders

sudo adduser plex www-data

# Add the Plex User to the www-data group to access Nextcloud folders (snap)

#sudo adduser root www-data

# Start PLEX

sudo systemctl start plexmediaserver

# Start Plex (snap)

#sudo snap start plexmediaserver

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $RESTLOGFILE_PATH
