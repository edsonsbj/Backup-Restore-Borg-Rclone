# **Nextcloud snap + PLEX**

This directory contains a script that performs the backup and restoration of your Nextcloud instance, including the data folder, as well as the PLEX server settings. The backup is done using Borg Backup and Rclone mount to store your backups in a cloud service of your choice.

## Contents <!-- omit in toc -->
- [Getting Started](#Getting-Started)
- [Backup](#Backup)
- [Installation of PLEX through Snap packages](#Installation-of-PLEX-through-Snap-packages)
- [Restore the Entire Server](#Restore-the-Entire-Server)
- [Restore Nextcloud](#Restore-Nextcloud)
- [Restore Settings](#Restore-Settings)
- [Restore Nextcloud/data](#Restore-Nextclouddata)
- [Restore PLEX](#Restore-PLEX)
- [Restore Data on Removable Media](#Restore-Data-on-Removable-Media)
  - [For NTFS, exFAT, and FAT32 formatted partitions and media](#For-NTFS-exFAT-and-FAT32-formatted-partitions-and-media)
- [Some important notes](#Some-important-notes)
- [Testing](#Testing)

## Getting Started

- Make sure that `Nextcloud` is already installed and working correctly.
- Check if `PLEX` is already installed on your system.
- Ensure that the programs `rclone`, `borg`, and `git` are installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the `example.conf` file and rename it according to your needs.
2. Add the folders you want to back up to the `patterns.lst` file. By default, the file is pre-configured to back up the `Nextcloud` folders, including the data folder, excluding the trash.
3. Set the variables in the `.conf` file to match your requirements.
4. Change the `CONFIG=”/path/to/.conf"` field in the `backup.sh` and `restore.sh` files to match the path to your `.conf` file.
5. Optionally, move the `backup.sh`, `patterns.lst`, `restore.sh`, and the newly edited `.conf` file to a folder of your preference.
6. Make the scripts executable using the command `sudo chmod +x`.
7. Replace the values `--config=/path/user/rclone.conf` and `Borg:` in the `Backup.service` file with appropriate settings, where `--config` corresponds to the location of your `rclone.conf` file, and `Borg:/` corresponds to your remote (cloud) to be mounted.
8. Move the `Backup.service` to the `/etc/systemd/system/` folder.
9. Execute the script `./backup.sh` or create a new Cron job using the command `crontab -e`, following the example below:

```
00 00 * * * sudo ./backup.sh
```

## PLEX Installation through Snap Packages

If PLEX was installed using the command `snap install plexmediaserver`, follow the steps below:

1. Comment out the lines related to PLEX in the `patterns.lst` file.
```
sudo sed -i '31s/^/# /g' "/path/to/patterns.lst"
sudo sed -i '11,14s/^/# /g' "/path/to/patterns.lst"
```
2. Uncomment the lines related to the snap in the `patterns.lst` file.
```
sudo sed -i '35s/^# //' "/path/to/patterns.lst"
sudo sed -i '18,21s/^# //' "/path/to/patterns.lst"
```
3. Change the variable `PLEX_CONF` to match the snap path in the `example.conf` file.
```
sudo sed -i "s/PLEX_CONF=\"\/var\/lib\/plexmediaserver\/Library\/Application Support\/Plex Media Server\"/PLEX_CONF=\"\/var\/snap\/plexmediaserver\/Library\/Application Support\/Plex Media Server\"/g" "/path/to/patterns.lst"
```
4. Make the necessary changes in the `backup.sh` and `restore.sh` scripts.
```
sudo sed -i 's/systemctl start plexmediaserver/snap start plexmediaserver/g' "/path/to/backup.sh"
sudo sed -i 's/systemctl stop plexmediaserver/snap stop plexmediaserver/g' "/path/to/backup.sh"
sudo sed -i 's/chown -R plex:plex/chown -R root:root/g' "/path/to/restore.sh"
sudo sed -i 's/systemctl start plexmediaserver/snap start plexmediaserver/g' "/path/to/restore.sh"
sudo sed -i 's/systemctl stop plexmediaserver/snap stop plexmediaserver/g' "/path/to/restore.sh"
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

- In your `restore.sh` file, comment out the range of lines below.

```
# Restore PLEX settings

echo "Restoring PLEX backup" >> $RESTLOGFILE_PATH

# Stop PLEX

sudo systemctl stop plexmediaserver

# Move the current PLEX folder
rm -rf $PLEX_CONF

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $PLEX_CONF >> $RESTLOGFILE_PATH 2>&1

# Restore permissions

chmod -R 755 $PLEX_CONF
chown -R plex:plex $PLEX_CONF

# Add PLEX User to the www-data group to access Nextcloud folders

sudo adduser plex root

# Start PLEX

sudo systemctl start plexmediaserver

echo
echo "DONE!"
```

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Settings**

This option will only restore the Nextcloud settings. Useful if the data folder is in another location.

- In your `restore.sh` file, comment out the range of lines below.
```
# Restore the ./data Nextcloud folder.
# Useful if the ./data folder is outside of /var/snap/nextcloud/common, otherwise, I recommend commenting out the line below, as your server will already be restored with the above command. 
# 
echo "Restoring ./data folder backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"
```

- Run the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Nextcloud/data**

To restore only the `./data` folder, follow the instructions below.

- In your `restore.sh` file, comment out the range of lines below. 

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

### **Restore PLEX**

To restore only PLEX settings, follow the instructions below.

- In your `restore.sh` file, comment out the range of lines below.

```
# Restore Nextcloud backup 
# 
echo "Restoring Nextcloud settings backup" >> $RESTLOGFILE_PATH

# Enable Maintenance Mode

echo
sudo nextcloud.occ

 maintenance:mode --on >> $RESTLOGFILE_PATH
echo 

# Extract the Files

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Check if the backup file exists
if [ -z "RESTORE_FILE" ]; then
    echo "No backup file found"
    exit 1
fi

sudo nextcloud.import -abc $RESTORE_FILE >> $RESTLOGFILE_PATH

echo
echo "DONE!"

# Restore the ./data Nextcloud folder.
# Useful if the ./data folder is outside of /var/snap/nextcloud/common, otherwise, I recommend commenting out the line below, as your server will already be restored with the above command. 
# 
echo "Restoring ./data folder backup" >> $RESTLOGFILE_PATH

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

### **Restore Data on Removable Media**

- Change the `DEVICE` and `MOUNTDIR` `NEXTCLOUD_DATA` variables in your `.conf` file.
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
 # If yes, grep the mount point and adjust $MOUNTDIR
 #  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
 #fi

 # Are there write and execute permissions?
 # [ ! -w "$MOUNTDIR" ] && {
 #  echo " No write permissions " >> $LOGFILE_PATH
 #  exit 1
 # }
 ```
### For NTFS exFAT and FAT32 formatted partitions and media

1. Add the following entry to the `/etc/fstab` file:

```
UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=root,gid=root,umask=0007,noatime,x-gvfs-show 0 0
```

2. Change the `UUID` to match the `UUID` of the drive to be mounted. To find the correct `UUID`, run the command `sudo blkid`.
3. Change `/mnt/Multimidia` to the mount point of your choice. If the mount point does not exist, create it using the command `sudo mkdir /mnt/your_mount_point`.
4. Change `ntfs-3g` to the desired partition format, such as exFAT or FAT32.
5. Run the command `sudo mount -a` to mount the drive.
6. If any errors occur when running the command above, install the `ntfs-3g` package for `NTFS` partitions, or the `exfat-fuse` and `exfat-utils` packages for `exFAT` partitions.

## Important Notes

- It is highly recommended to unmount the local drive where the backup was made after the process is complete. To do this, schedule a Cron job to unmount the drive three hours after the backup starts. For example:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

This will ensure that Rclone has enough time to complete the file upload to the cloud before unmounting the drive.

## Testing

In tests conducted, the elapsed time for backup and restoration was similar to other tools such as `Duplicity` or `Deja-Dup`.

