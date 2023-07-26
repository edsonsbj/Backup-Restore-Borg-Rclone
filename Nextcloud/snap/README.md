# **Nextcloud snap**

This directory contains a script that performs backup and restoration of your Nextcloud instance, including the data folder. The backup is done using Borg Backup and Rclone mounting to store your backups in a cloud service of your choice.

## Contents <!-- omit in toc -->
- [Getting Started](#Getting-Started)
- [Backup](#Backup)
- [Restoration](#Restoration)
  - [Restore the Entire Server](#Restore-the-Entire-Server)
  - [Restore Settings](#Restore-Settings)
  - [Restore Nextcloud/data](#Restore-Nextclouddata)
  - [Restore Data on Removable Media](#Restore-Data-on-Removable-Media)
    - [For NTFS, exFAT, and FAT32 formatted partitions and media](#For-NTFS-exFAT-and-FAT32-formatted-partitions-and-media)
- [Some important notes](#Some-important-notes)
- [Testing](#Testing)

## Getting Started

- Make sure that `Nextcloud` is already installed and working correctly.
- Ensure that the programs `rclone`, `borg`, and `git` are installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the `example.conf` file and rename it according to your needs.
2. Add the folders you want to back up to the `patterns.lst` file. By default, the file is pre-configured to back up the `Nextcloud` folders, including the data folder, excluding the trash.
3. Set the variables in the `.conf` file to match your requirements.
4. Optionally, move the `backup.sh`, `patterns.lst`, `restore.sh`, and the newly edited `.conf` file to a folder of your preference.
5. Make the scripts executable using the command `sudo chmod +x`.
6. Replace the values `--config=/path/user/rclone.conf` and `Borg:` in the `Backup.service` file with appropriate settings, where `--config` corresponds to the location of your `rclone.conf` file, and `Borg:/` corresponds to your remote (cloud) to be mounted.
7. Move the `Backup.service` to the `/etc/systemd/system/` folder.
8. Execute the script `./backup.sh` or create a new Cron job using the command `crontab -e`, following the example below:

```
00 00 * * * sudo ./backup.sh
```

## **Restoration**

Restoration options:

### **Restore the Entire Server**

Restore all files.

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Settings**

This option will only restore Nextcloud settings. Useful if the data folder is in a different location.

- In your `restore.sh` file, comment out the range of lines below.

 ```
# Restores the ./data Nextcloud folder.
# Useful if the ./data folder is outside of /var/snap/nextcloud/common; otherwise, I recommend commenting the line below, as your server will already be restored with the above command.
# 
echo "Restoring backup from the ./data folder" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"
```

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Nextcloud/data**

To restore only the `./data` folder, follow the instructions below.

- In your `restore.sh` file, comment out the range of lines below.

```
# Restores Nextcloud settings.
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

- Execute the script with the desired backup date to be restored.

```
./restore.sh 2023-07-15
```

### **Restore Data on Removable Media**

- Change the variables `DEVICE` and `MOUNTDIR` `NEXTCLOUD_DATA` in your `.conf` file.
- In your `restore.sh` file, uncomment the following lines.

 ```
 # DO NOT MODIFY
 # MOUNT_FILE="/proc/mounts"
 # NULL_DEVICE="1> /dev/null 2>&1"
 # REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1" 

 # Is the device mounted?
 # grep -q "$DEVICE" "$MOUNT_FILE"
 # if [ "$?" != "0" ]; then
 # If not, mount to $MOUNTDIR
 #  echo " Device not mounted. Mounting $DEVICE " >> $LOGFILE_PATH
 #  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
 #else
 # If yes, grep the mount point and change $MOUNTDIR
 #  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
 #fi

 # Are there write and read permissions?
 # [ ! -w "$MOUNTDIR" ] && {
 #  echo " Does not have write permissions " >> $LOGFILE_PATH
 #  exit 1
 # }
 ```
### For NTFS, exFAT, and FAT32 formatted partitions and media

1. Add the following entry to the `/etc/fstab` file:

```
UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=root,gid=root,umask=0007,noatime,x-gvfs-show 0 0
```
<details>
<summary>Click here to expand</summary>

2. Change the `UUID` to match the `UUID` of the drive to be mounted. To find the correct `UUID`, run the command `sudo blkid`.
3. Change `/mnt/Multimidia` to your preferred mount point. If the mount point doesn't exist, create it using the command `sudo mkdir /mnt/your_mount_point`.
4. Change `ntfs-3g` to the desired partition format, such as exFAT or FAT32.
5. Run the command `sudo mount -a` to mount the drive.
6. If there's an error executing the above command, install the `ntfs-3g` package for `NTFS` partitions or `exfat-fuse` and `exfat-utils` for `exFAT` partitions.

## Some important notes

- It is highly recommended to unmount the local drive where the backup was made after the process is completed. To do this, schedule a Cron job to unmount the drive within 3 hours of starting the backup. For example:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

This will ensure that Rclone has enough time to complete the file upload to the cloud before unmounting the drive.

## Testing

In tests conducted, the elapsed time for backup and restoration was similar to other tools such as `Duplicity` or `Deja-Dup`.
