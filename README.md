# Backup and Restoration Scripts using Borg Backup and Rclone

This repository contains scripts for performing backup and restoration tasks using the Borg and Rclone tools. Rclone is utilized to mount a cloud service of your preference onto a local drive, enabling backup and restoration operations.

## Getting Started

- Ensure that the `rclone`, `borg`, and `git` programs are already installed on your system.
- Clone this repository using the command `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Make a copy of the `example.conf` file and rename it according to your needs.
2. Add the folders you wish to back up to the `patterns.lst` file.
3. Set the variables in the `.conf` file to match your requirements.
4. Optionally, move the `backup.sh`, `patterns.lst`, `restore.sh`, and the newly edited `.conf` file to a folder of your preference.
5. Make the scripts executable using the command `sudo chmod +x`.
6. Replace the values `--config=/path/user/rclone.conf` and `Borg:` in the `Backup.service` file with appropriate settings, where `--config` corresponds to the location of your `rclone.conf` file, and `Borg:/` corresponds to your remote (cloud) to be mounted.
7. Move the `Backup.service` to the `/etc/systemd/system/` folder.
8. Execute the script `./backup.sh` or create a new Cron job using the command `crontab -e`, following the example below:

```
00 00 * * * sudo ./backup.sh
```

## Restoration

Restore all files.

- Execute the script with the desired backup date to be restored along with the file or directory you want to restore.

```
./restore.sh 2023-07-15 home/
```

### Restore data on removable media

- Change the variables `DEVICE` and `MOUNTDIR` `NEXTCLOUD_DATA` in your `.conf` file.
- In your `restore.sh` file, uncomment the following lines:

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
#}
```

## Some important notes

- It is highly recommended to unmount the local drive where the backup was made after the process is completed. To do this, schedule a Cron job to unmount the drive within 3 hours of starting the backup. For example:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

This will ensure that Rclone has enough time to complete the file upload to the cloud before unmounting the drive.

## Testing

In tests conducted, the elapsed time for backup and restoration was similar to other tools such as `Duplicity` or `Deja-Dup`.

# Nextcloud

In this directory, you will find two scripts for performing backup and restoration of Nextcloud, depending on the type of installation you have: manual (Apache + MySQL + PHP) or via snap packages.

# Nextcloud + Plex

Use this script if you have a Nextcloud server and Plex on the same machine. Inside the folder, there are two script options, one for each type of Nextcloud installation.

# Nextcloud + Emby (Jellyfin)

Use this script if you have a Nextcloud server and Emby on the same machine. Inside the folder, there are two script options, one for each type of Nextcloud installation. Additionally, you can modify the script if you use Jellyfin instead of Emby.
