#!/bin/bash

CONFIG="/path/to/.conf"
. $CONFIG

# Some helpers and error handling:
info() { printf "\n%s %s\n\n" "$(date)" "$*" >&2; }
trap 'echo "$(date) Backup interrupted" >&2; exit 2' INT TERM

#
# Check if the script is executed by root
#
if [ "$(id -u)" != "0" ]
then
        errorecho "ERROR: This script must be executed as root!"
        exit 1
fi

#
# Uncomment the following lines if you need to restore files or folders from external storage devices such as pendrives and external hard drives.

# DO NOT MODIFY
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1"

# Is the device mounted?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
  # If not, mount it to $MOUNTDIR
#  echo "Device not mounted. Mount $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
#  # If yes, grep the mount point and set $MOUNTDIR accordingly
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Are there write and read permissions?
# [ ! -w "$MOUNTDIR" ] && {
#  echo "No write permissions " >> $LOGFILE_PATH
#  exit 1
# }

info "Restoration Started" 2>&1 | tee -a $RESTLOGFILE_PATH

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

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; } 

# Create the necessary folders

mkdir /mnt/rclone/Borg /var/log/Rclone /var/log/Borg

# Mount Rclone

sudo systemctl start Backup.service

# Restore Nextcloud backup

echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

# Enable Maintenance Mode

echo
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --on >> $RESTLOGFILE_PATH
echo 

# Stop Apache

systemctl stop apache2

# Remove the current Nextcloud folder

rm -rf $NEXTCLOUD_CONF

# Extract Files

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore the database

echo "Restoring database" >> $RESTLOGFILE_PATH

mysql -u --host=$HOSTNAME --user=$USER_NAME --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH

echo
echo "DONE!"

# Restore the ./data folder in Nextcloud.
# Useful if the ./data folder is outside /var/www/nextcloud, otherwise it is recommended to comment the line below, as your server will already be restored with the above command. 

echo "Restoring ./data folder backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore permissions

chmod -R 770 $NEXTCLOUD_DATA 
chmod -R 755 $NEXTCLOUD_CONF
chown -R www-data:www-data $NEXTCLOUD_DATA
chown -R www-data:www-data $NEXTCLOUD_CONF

# Start Apache

systemctl start apache2

# Disable Maintenance Mode in Nextcloud

echo  
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --off >> $RESTLOGFILE_PATH
echo

echo
echo "DONE!"

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

# For NTFS and FAT32 file systems, and others that do not accept permissions, it is convenient to add an entry to your /etc/fstab file. Uncomment the line below and change the UUID /mnt/YOURHD and ntfs-3g field accordingly.
# To find the UUID of your partition or HD, run the command sudo blkid.

#cp /etc/fstab /etc/fstab.bk
#sudo cat <<EOF >>/etc/fstab
#UUID=089342544239044F /mnt/YOURHD ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
#EOF

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $RESTLOGFILE_PATH
