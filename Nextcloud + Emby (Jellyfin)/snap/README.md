# **Nextcloud snap + Emby (jellyfin)**

This directory contains a script that performs the backup and restoration of your Nextcloud instance, including the data folder, as well as the Emby or Jellyfin server settings. The backup is done using Borg Backup and Rclone mount to store your backups in a cloud service of your choice.

## Getting Started

- Ensure that `Nextcloud` is already installed and working correctly.
- Check if `Emby` or `Jellyfin` is already installed on your system.
- Verify that the programs `rclone`, `borg`, and `git` are already installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the `example.conf` file and rename it according to your needs.
2. Add the folders you want to back up in the `patterns.lst` file. By default, the file is already pre-configured to back up the `Nextcloud` folders, including the data folder, excluding the trash bin, and also the `Emby` configuration folder.
3. Set the variables in the `.conf` file to match your needs.
4. Optionally, move the `backup.sh`, `patterns.lst`, `restore.sh`, and the edited `.conf` file to a folder of your choice.
5. Make the scripts executable using the command `sudo chmod +x`.
6. Replace the values `--config=/path/user/rclone.conf` and `Borg:`/ in the `Backup.service` file with the appropriate configurations, where `--config` corresponds to the location of your `rclone.conf` file and `Borg:/` corresponds to your remote (cloud) to be mounted.
7. Move the `Backup.service` to the `/etc/systemd/system/` folder.
8. Run the script `./backup.sh` or create a new Cron job using the `crontab -e` command, as shown below:

````
00 00 * * * sudo ./backup.sh
````

## **Jellyfin instead of Emby**

If you chose to use `Jellyfin` instead of `Emby`, execute the commands below:

1. Comment the lines referring to Emby in the `patterns.lst` file:

```
sudo sed -i '8,13s/^/# /g' "/path/to/patterns.lst"
```

2. Uncomment the line referring to Jellyfin in the `patterns.lst` file:

```
sudo sed -i '16s/^# //' "/path/to/patterns.lst"
```

3. Change the `EMBY_CONF` variable to match the path of the Jellyfin settings in the `example.conf` file:

```
sudo sed -i "s/\EMBY_CONF=\"\/var\/lib\/emby\"/\$EMBY_CONF=\"\/var\/lib\/jellyfin\"/g" "/path/to/patterns.lst"
```

4. Make the necessary changes to the `backup.sh` and `restore.sh` scripts.

```
sudo sed -i 's/emby-server.service/jellyfin.service/g' "/path/to/backup.sh"
sudo sed -i 's/chown -R emby:emby/chown -R jellyfin:jellyfin/g' "/path/to/restore.sh"
sudo sed -i 's/sudo adduser emby www-data/sudo adduser jellyfin www-data/g' "/path/to/restore.sh"
sudo sed -i 's/emby-server.service/jellyfin.service/g' "/path/to/restore.sh"
```

## **Restoration**

Restoration options:

### **Restore the Entire Server**

Restores all files.

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Nextcloud**

To restore only Nextcloud, follow the instructions below.

- In your `restore.sh` file, comment out the lines below.

```
# Restore Emby settings

echo "Restoring Emby backup" >> $RESTLOGFILE_PATH

# Stop Emby

sudo systemctl stop emby-server.service

# Move the current Emby folder
rm -rf $EMBY_CONF

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $EMBY_CONF >> $RESTLOGFILE_PATH 2>&1

# Restore permissions

chmod -R 755 $EMBY_CONF
chown -R emby:emby $EMBY_CONF

# Add Emby User to www-data group to access Nextcloud folders

sudo adduser emby root

# Start Emby

sudo systemctl start emby-server.service

echo
echo "DONE!"
```

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Settings**

This option will restore only Nextcloud settings. Useful if the data folder is in another location.

- In your `restore.sh` file, comment out the lines below.

 ```
# Restore Nextcloud data folder.
# Useful if the data folder is outside of /var/snap/nextcloud/common, otherwise, I recommend commenting the line below since your server will already be restored with the command above. 
# 
echo "Restoring data folder backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"
```

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Nextcloud/data**

To restore only the data folder, follow the instructions below.

- In your `restore.sh` file, comment out the lines below. 

```
# Restore Nextcloud settings 
# 
echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

# Check if the backup file exists
if [ -z "RESTORE_FILE" ]; then
    echo "No backup file found"
    exit 1
fi

sudo nextcloud.import -abc $RESTORE_FILE >> $RESTLOGFILE_PATH

echo
echo "DONE!"
```

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Emby**

To restore only the Emby settings, follow the instructions below.

- In your `restore.sh` file, comment out the lines below.

```
# Restore Nextcloud backup 
# 
echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

# Enable Maintenance Mode

echo
sudo nextcloud.occ maintenance:mode --on >> $RESTLOGFILE_PATH
echo 

# Extract Files

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Check if the backup file exists
if [ -z "RESTORE_FILE" ]; then
    echo "No backup file found"
    exit 1
fi

sudo nextcloud.import -

abc $RESTORE_FILE >> $RESTLOGFILE_PATH

echo
echo "DONE!"

# Restore Nextcloud data folder.
# Useful if the data folder is outside of /var/snap/nextcloud/common, otherwise, I recommend commenting the line below since your server will already be restored with the command above. 
# 
echo "Restoring data folder backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore permissions 

chmod -R 770 $NEXTCLOUD_DATA 
chown -R root:root $NEXTCLOUD_DATA
chown -R root:root $NEXTCLOUD_CONF

# Disable Nextcloud Maintenance Mode

echo  
sudo nextcloud.occ maintenance:mode --off >> $RESTLOGFILE_PATH
echo

echo
echo "DONE!"
```

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restoring data on removable media**

- Change the variables `DEVICE` and `MOUNTDIR` in your `.conf` file `NEXTCLOUD_DATA`.
- In your `restore.sh` file, uncomment the following lines. 
 ```
# DO NOT CHANGE
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1" 

# Is the Device Mounted?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
# If not, mount it at $MOUNTDIR
#  echo " Device not mounted. Mount $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
# If yes, grep the mount point and change the $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi
# Are there write and read permissions?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " No write permissions " >> $LOGFILE_PATH
#  exit 1
# }
```

### **For NTFS exFAT and FAT32 Partitions and Media**

1. Add the following entry in the `/etc/fstab` file:

```
UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=root,gid=root,umask=0007,noatime,x-gvfs-show 0 0
```

2. Change the `UUID` to match the `UUID` of the drive to be mounted. To find the correct `UUID`, run the `sudo blkid` command.
3. Change `/mnt/Multimidia` to the mount point of your choice. If the mount point does not exist, create it using the command `sudo mkdir /mnt/your_mount_point`.
4. Change `ntfs-3g` to the desired partition format, such as exFAT or FAT32.
5. Run the command `sudo mount -a` to mount the drive.
6. If there are any errors when running the command above, install the `ntfs-3g` package for `NTFS` partitions or `exfat-fuse` and `exfat-utils` packages for `exFAT` partitions.

## Some important notes

- It is highly recommended to unmount the local drive where the backup was made after the process is completed. To do this, create a schedule in Cron to unmount the drive within 3 hours after starting the backup. For example:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

This will ensure that Rclone has enough time to complete the upload of files to the cloud before unmounting the drive.

## Tests

In conducted tests, the elapsed time for backup and restoration was similar to other tools such as `Duplicity` or `Deja-Dup`.
