# Nextcloud server + PLEX

This directory contains a script that performs the backup and restoration of your Nextcloud instance, including the data folder, as well as the PLEX server settings. The backup is done using Borg Backup and Rclone mount to store your backups in a cloud service of your choice.

## Getting Started

- Make sure that `Nextcloud` is already installed and working properly.
- Check if `PLEX` is already installed on your system.
- Check if the programs `rclone`, `borg` and `git` are already installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the file `example.conf` and rename it according to your needs.
2. Add the folders you want to backup in the file `patterns.lst`. By default, the file is already pre-configured to backup the `Nextcloud` folders, including the data folder, excluding the trash bin and also the configuration folder of `PLEX`.
3. Set the variables in the `.conf` file to match your needs.
4. Optionally, move the files `backup.sh`, `patterns.lst`, `restore.sh` and the newly edited `.conf` file to a folder of your preference.
5. Make the scripts executable using the command `sudo chmod +x`.
6. Replace the values `--config=/path/user/rclone.conf` and `Borg:`/ in the file `Backup.service` with the appropriate settings, where `--config` corresponds to the location of your `rclone.conf` file and `Borg:/` corresponds to your remote (cloud) to be mounted.
7. Move the `Backup.service` to the folder `/etc/systemd/system/`.
8. Run the script `./backup.sh` or create a new job in Cron using the command `crontab -e`, as shown below:

```
00 00 * * * sudo ./backup.sh
```

## Installation of PLEX through Snap packages

If PLEX was installed using the command `snap install plexmediaserver`, follow the steps below:

1. Comment out the lines referring to PLEX in the file `patterns.lst`.
```
sudo sed -i '31s/^/# /g' "/path/to/patterns.lst"
sudo sed -i '11,14s/^/# /g' "/path/to/patterns.lst"
```
2. Uncomment the lines referring to snap in the file `patterns.lst`.
```
sudo sed -i '35s/^# //' "/path/to/patterns.lst"
sudo sed -i '18,21s/^# //' "/path/to/patterns.lst"
```
3. Change the variable `PLEX_CONF` to match the snap path in the file `example.conf`.
```
sudo sed -i "s/PLEX_CONF=\"\/var\/lib\/plexmediaserver\/Library\/Application Support\/Plex Media Server\"/PLEX_CONF=\"\/var\/snap\/plexmediaserver\/Library\/Application Support\/Plex Media Server\"/g" "/path/to/patterns.lst"
```
4. Make the necessary changes in the script `backup.sh` and `restore.sh`.
```
sudo sed -i 's/systemctl start plexmediaserver/snap start plexmediaserver/g' "/path/to/backup.sh"
sudo sed -i 's/systemctl stop plexmediaserver/snap stop plexmediaserver/g' "/path/to/backup.sh"
sudo sed -i 's/chown -R plex:plex/chown -R root:root/g' "/path/to/restore.sh"
sudo sed -i 's/systemctl start plexmediaserver/snap start plexmediaserver/g' "/path/to/restore.sh"
sudo sed -i 's/systemctl stop plexmediaserver/snap stop plexmediaserver/g' "/path/to/restore.sh"
```

## Restoration

Restoration options:

### Restore the entire server

Restores all files.

- Run the script with the desired date of the backup to be restored.

```
./restore.sh 2023-07-15
```

### Restore Nextcloud

To restore only Nextcloud, follow the instructions below.

- In your file `restore.sh`, comment out the range of lines below.

```
# Restore PLEX settings

echo "Restoring PLEX backup" >> $RESTLOGFILE_PATH

# Stop PLEX

sudo systemctl stop plexmediaserver

# Remove the current Plex folder
rm -rf $PLEX_CONF

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $PLEX_CONF >> $RESTLOGFILE_PATH 2>&1

# Restore permissions

chmod -R 755 PLEX_CONF
chown -R plex:plex PLEX_CONF

# Add PLEX User to www-data group to access Nextcloud folders

sudo adduser plex www-data

# Start PLEX

sudo systemctl start plexmediaserver

echo
echo "DONE!"
```

- Run the script with the desired date of the backup to be restored.

```
./restore.sh 2023-07-15
```

### Restore Nextcloud/data

To restore only the ./data folder, follow the instructions below.

- In your `restore.sh` file, comment out the range of lines below.

```
# Restore Nextcloud backup

echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

Restore database

echo "Restoring database" >> $RESTLOGFILE_PATH

mysql -u --host=$HOSTNAME --user=$user --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH

echo
echo "DONE!"
```

- Run the script with the desired date of the backup to be restored.

```
./restore.sh 2023-07-15
```

### Restore PLEX

To restore only the PLEX settings, follow the instructions below.

- In your `restore.sh` file, comment out the range of lines below.

```
# Restore Nextcloud backup

echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

# Enabling Nextcloud Maintenance Mode
echo
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --on >> $RESTLOGFILE_PATH
echo

# Stop Apache
systemctl stop apache2

# Remove current Nextcloud folder
rm -rf $NEXTCLOUD_CONF

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore database
echo "Restoring database" >> $RESTLOGFILE_PATH
mysql -u --host=$HOSTNAME --user=$user --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH
echo
echo "DONE!"

# Restore Nextcloud ./data folder.
# Useful if the ./data folder is outside /var/www/nextcloud otherwise I recommend commenting out the line below, as your server will already be restored with the command above.
echo "Restoring backup of ./data folder" >> $RESTLOGFILE_PATH
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

# Disabling Nextcloud Maintenance Mode
echo
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --off >> $RESTLOGFILE_PATH
echo
```
- Run the script with the desired date of the backup to be restored.

```
./restore.sh 2023-07-15
```

### Restore data on removable media

- Change the variables `DEVICE` and `MOUNTDIR` `NEXTCLOUD_DATA` in your `.conf` file.
- In your `restore.sh` file, uncomment the lines below.

```
# DO NOT CHANGE
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1"

# Is device mounted?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
# If not, mount on $MOUNTDIR
# echo "Device not mounted. Mounting $DEVICE" >> $LOGFILE_PATH
# eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
# If yes, grep the mount point and change $MOUNTDIR
# DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Are there write and record permissions?
# [! -w "$MOUNTDIR"] && {
# echo "No write permissions" >> $LOGFILE_PATH
# exit 1
#}
```

### For partitions and media in NTFS exFAT and FAT32 format

1. Add the following entry to the /etc/fstab file:
```
UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
```
2. Change the `UUID` to match the `UUID` of the drive to be mounted. To find the correct `UUID`, run the `sudo blkid` command.
3. Change `/mnt/Multimidia` to your preferred mount point. If the mount point does not exist, create it using the `sudo mkdir /mnt/your_mountpoint` command.
4. Change `ntfs-3g` to the desired partition format, such as `exFAT or FAT32`.
5. Run the `sudo mount -a` command to mount the drive.
6. If an error occurs when running the above command, install the `ntfs-3g` packages for `NTFS` partitions or `exfat-fuse and exfat-utils` for `exFAT` partitions.

## Some important observations

- It is highly recommended to unmount the local drive where the backup was made after completion of the process. To do this, create a Cron schedule to unmount the drive at an interval of 3 hours after starting the backup. For example:
```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```
This will ensure that Rclone has enough time to complete uploading files to the cloud before unmounting the drive.

## Tests
In tests performed, the elapsed time for backup and restoration was similar to other tools such as Duplicity or Deja-Dup.
