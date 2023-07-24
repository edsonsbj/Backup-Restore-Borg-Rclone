# **Nextcloud server + Emby (jellyfin)**

This directory contains a script that performs the backup and restoration of your Nextcloud instance, including the data folder, as well as the Emby or Jellyfin server settings. The backup is done using Borg Backup and Rclone mount to store your backups in a cloud service of your choice.

## Getting Started

- Make sure that `Nextcloud` is already installed and working correctly.
- Check if `Emby` or `Jellyfin` is already installed on your system.
- Verify that the programs `rclone`, `borg`, and `git` are installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the `example.conf` file and rename it according to your needs.
2. Add the folders you wish to back up to the `patterns.lst` file. By default, the file is already pre-configured to back up the `Nextcloud` folders, including the data folder, excluding the trash, and also the `Emby` configuration folder.
3. Set the variables in the `.conf` file to match your requirements.
4. Optionally, move the files `backup.sh`, `patterns.lst`, `restore.sh`, and the edited `.conf` file to a folder of your preference.
5. Make the scripts executable using the command `sudo chmod +x`.
6. Replace the values `--config=/path/user/rclone.conf` and `Borg:/` in the `Backup.service` file with the appropriate settings, where `--config` corresponds to the location of your `rclone.conf` file and `Borg:/` corresponds to your remote (cloud) to be mounted.
7. Move the `Backup.service` to the `/etc/systemd/system/` folder.
8. Run the script `./backup.sh` or create a new job in Cron using the command `crontab -e`, as shown below:

````
00 00 * * * sudo ./backup.sh
````

## **Jellyfin instead of Emby**

If you opted to use `Jellyfin` instead of `Emby`, execute the following commands:

1. Comment out the lines referring to Emby in the `patterns.lst` file.
````
sudo sed -i '8,13s/^/# /g' "/path/to/patterns.lst"
````
2. Uncomment the line referring to Jellyfin in the `patterns.lst` file.
````
sudo sed -i '16s/^# //' "/path/to/patterns.lst"
````
3. Change the `EMBY_CONF` variable to match the path of the Jellyfin settings in the `example.conf` file.
````
sudo sed -i "s/\EMBY_CONF=\"\/var\/lib\/emby\"/\$EMBY_CONF=\"\/var\/lib\/jellyfin\"/g" "/path/to/patterns.lst"
````
4. Make the necessary changes in the `backup.sh` and `restore.sh` scripts.
````
sudo sed -i 's/emby-server.service/jellyfin.service/g' "/path/to/backup.sh"
sudo sed -i 's/chown -R emby:emby/chown -R jellyfin:jellyfin/g' "/path/to/restore.sh"
sudo sed -i 's/sudo adduser emby www-data/sudo adduser jellyfin www-data/g' "/path/to/restore.sh"
sudo sed -i 's/emby-server.service/jellyfin.service/g' "/path/to/restore.sh"
````

## **Restoration**

Restoration Options:

### **Restore the Entire Server**

Restore all files

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Nextcloud**

To restore only Nextcloud, follow the instructions below.

- In your `restore.sh` file, comment out the following lines:

```
# Restore Emby configurations

echo "Restoring Emby backup" >> $RESTLOGFILE_PATH

# Stop Emby

sudo systemctl stop emby-server.service

# Move the current Emby folder
mv -rf $EMBY_CONF $EMBY_CONF.bk

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $EMBY_CONF >> $RESTLOGFILE_PATH 2>&1

# Restore permissions

chmod -R 755 $EMBY_CONF
chown -R emby:emby $EMBY_CONF

# Add Emby User to www-data group to access Nextcloud folders

sudo adduser emby www-data

# Start Emby

sudo systemctl start emby-server.service

echo
echo "DONE!"
 ```

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Nextcloud/data**

To restore only the ./data folder, follow the instructions below.

- In your `restore.sh` file, comment out the following lines:

```
# Restore Nextcloud configurations 

echo "Restoring Nextcloud backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore the database

echo "Restoring the database" >> $RESTLOGFILE_PATH

mysql -u --host=$HOSTNAME --user=$USER_NAME --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH

echo
echo "DONE!"
```

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Emby**

To restore only Emby's configurations, follow the instructions below.

- In your `restore.sh` file, comment out the following lines:

```
# Restore Nextcloud configurations 

echo "Restoring Nextcloud backup" >> $RESTLOGFILE_PATH
# Enable Nextcloud Maintenance Mode

echo
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --on >> $RESTLOGFILE_PATH
echo

# Stop Apache

systemctl stop apache2

# Remove the current Nextcloud folder
rm -rf $NEXTCLOUD_CONF

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restore the database

echo "Restoring the database" >> $RESTLOGFILE_PATH

mysql -u --host=$HOSTNAME --user=$USER_NAME --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH

echo
echo "DONE!"

# Restore the ./data folder of Nextcloud.
# Useful if the ./data folder is outside /var/www/nextcloud; otherwise, I recommend commenting out the line below, as your server will already be restored with the above command.
# 
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

# Disable Nextcloud Maintenance Mode

echo
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --off >> $RESTLOGFILE_PATH
echo
```

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Data to Removable Media**

- Change the `DEVICE` and `MOUNTDIR` variables in your `.conf` file to match `NEXTCLOUD_DATA`.
- In your `restore.sh` file, uncomment the following lines:
```
# DO NOT CHANGE
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1" 

# Is the Device Mounted?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
# If not, mount it to $MOUNTDIR
# echo " Device not mounted. Mounting $DEVICE " >> $LOGFILE_PATH
# eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
# If yes, grep the mount point and set the $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Does it have write and execute permissions?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " No write permissions " >> $LOGFILE_PATH
#  exit 1
# }
```

### **For Partitions and Media in NTFS, exFAT, and FAT32 Formats**

1. Add the following entry to the `/etc/fstab` file:

```
UUID=089342544239044F /mnt/Multimedia ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
```
2. Change the `UUID` to match the `UUID` of the drive to be mounted. To find the correct `UUID`, run the command `sudo blkid`.
3. Change `/mnt/Multimedia` to the desired mount point. If the mount point does not exist, create it using the command `sudo mkdir /mnt/your_mount_point`.
4. Change `ntfs-3g` to the desired partition format, such as exFAT or FAT32.
5. Run the command `sudo mount -a` to mount the drive.
6. If any errors occur while running the command above, install the `ntfs-3g` package for NTFS partitions or the `exfat-fuse` and `exfat-utils` packages for exFAT partitions.

## Some Important Notes

- It is highly recommended to unmount the local drive where the backup was made after the process is complete. To do this, schedule a Cron job to unmount the drive 3 hours after the backup starts. For example:

````
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
````

- This ensures that Rclone has enough time to complete uploading the files to the cloud before unmounting the drive.

## Tests

In tests conducted, the elapsed time for backup and restoration was similar to that of other tools such as `Duplicity` or `Deja-Dup`.
