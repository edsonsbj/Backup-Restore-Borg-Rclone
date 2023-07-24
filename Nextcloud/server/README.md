# Nextcloud server

This directory contains a script that performs the backup and restoration of your Nextcloud instance, including the data folder. The backup is done using Borg Backup and Rclone mount to store your backups in a cloud service of your choice.

## Getting Started

- Make sure that `Nextcloud` is already installed and working properly.
- Check if the programs `rclone`, `borg` and `git` are already installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the file `example.conf` and rename it according to your needs.
2. Add the folders you want to backup in the file `patterns.lst`. By default, the file is already pre-configured to backup the `Nextcloud` folders, including the data folder, excluding the trash bin.
3. Set the variables in the `.conf` file to match your needs.
4. Optionally, move the files `backup.sh`, `patterns.lst`, `restore.sh` and the newly edited `.conf` file to a folder of your preference.
5. Make the scripts executable using the command `sudo chmod +x`.
6. Replace the values `--config=/path/user/rclone.conf` and `Borg:`/ in the file `Backup.service` with the appropriate settings, where `--config` corresponds to the location of your `rclone.conf` file and `Borg:/` corresponds to your remote (cloud) to be mounted.
7. Move the `Backup.service` to the folder `/etc/systemd/system/`.
8. Run the script `./backup.sh` or create a new job in Cron using the command `crontab -e`, as shown below:

```
00 00 * * * sudo ./backup.sh
```

## Restoration

Restoration options:

### Restore the entire server

Restores all files.

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
# If not, mount at $MOUNTDIR
#  echo " Device not mounted. Mounting $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
# If yes, grep mount point and change $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Are there write and read permissions?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " No write permissions " >> $LOGFILE_PATH
#  exit 1
#}
```

### For partitions and media in NTFS exFAT and FAT32 format

1. Add the following entry in the `/etc/fstab` file:

```
UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
```

2. Change the UUID to match the UUID of the drive to be mounted. To find the correct UUID, run the command `sudo blkid`.
3. Change /mnt/Multimidia to the mount point of your preference. If the mount point does not exist, create it using the command `sudo mkdir /mnt/your_mountpoint`.
4. Change ntfs-3g to the desired partition format, such as exFAT or FAT32.
5. Run the command `sudo mount -a` to mount the drive.
6. If any error occurs when running the command above, install the packages ntfs-3g for NTFS partitions or exfat-fuse and exfat-utils for exFAT partitions.

## Some important notes

- It is highly recommended to unmount the local drive where the backup was made after the process is completed. To do this, create a schedule in Cron to unmount the drive at an interval of 3 hours after the backup start. For example:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

This will ensure that Rclone has enough time to complete the upload of files to the cloud before unmounting the drive.

## Tests

In tests performed, the elapsed time for backup and restoration was similar to that of other tools such as Duplicity or Deja-Dup.
