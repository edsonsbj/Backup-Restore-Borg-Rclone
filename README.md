# Backup-Restore

This repository contains scripts for performing backup and restoration tasks using Borg. These are Bash scripts for backup/restore of [Nextcloud](https://nextcloud.com/) and media servers like [Emby](https://emby.media/), [Jellyfin](https://jellyfin.org/), and [Plex](https://www.plex.tv/), all of which are installed on the same machine.

## General Information

To perform a full backup of any Nextcloud instance along with a media server like Plex, you will need to back up the following items:
- The Nextcloud **file directory** (usually */var/www/nextcloud*)
- The **data directory** of Nextcloud (it's recommended not to be located in the web root, e.g., */var/nextcloud_data*)
- The Nextcloud **database**
- The Media Server **file directory** (usually */var/lib or /var/snap*)

With these scripts, all these elements can be included in a backup.

## Important Notes About Using the Scripts

- After cloning or downloading the scripts, they need to be set up by running the `setup.sh` script (see below).
- If you don't want to use the automated setup, you can also use the `BackupRestore.conf.sample` file as a starting point. Just make sure to rename the file when you're done (`cp BackupRestore.conf.sample BackupRestore.conf`).
- The configuration file `BackupRestore.conf` has to be located in the same directory as the backup/restore scripts.
- If using the scripts for Backup or Restoration of Nextcloud, Plex, or Emby servers, the scripts in this repository assume that the programs were installed via `apt-get` or `dpkg` (Media Server).

## Automated Setup

1. Run the following command in a terminal with administrator privileges:
   ```
   wget https://raw.githubusercontent.com/edsonsbj/Backup-Restore-Borg/main/setup.sh && sudo chmod 700 *.sh && ./sudo setup.sh
   ```
2. After running the interactive script `setup.sh`, the `Backup.sh` and `Restore.sh` scripts will be generated based on your selection, along with the `BackupRestore.conf` for using the script, and configuring cron.
3. **Important**: Check that all files were created and must be in /root/Scripts.
4. **Important**: Check the configuration file to ensure everything was set up correctly (see *TODO* in the configuration file comments).
5. Start using the scripts: See sections *Backup* and *Restore* below.

Keep in mind that the configuration file `BackupRestore.conf` has to be located in the same directory as the backup/restore scripts, or the configuration will not be found.

## Manual Setup

1. Install Git if it is not already installed.
2. Clone this repository or download and unzip the zip file: `git clone https://github.com/edsonsbj/Backup-Restore-Borg.git`
3. Choose the script you want to use for backup and restore and delete the others. Remember that the scripts in the root folder are intended to back up all the files on your system, useful if you are not interested in backing up and restoring Nextcloud, Emby, Jellyfin, and Plex servers.
4. Copy the `BackupRestore.conf.sample` file to `BackupRestore.conf`, which must be in the same folder as the scripts.
5. Make the scripts executable with: `chmod 700 *.sh`

## Performing Backup or Restoration

### Backup

If you chose option 1 >> Backup in the automated setup.sh script, or you cloned the entire repository to use and want to use the scripts contained in the repository root, run the script like this:
   ```
   sudo ./Backup.sh
   ```

### Media Server

If you selected option 3 >> Backup in the automated setup.sh script, or downloaded the Media Server folder, run the script as follows:
   ```
   sudo ./Backup.sh
   ```

Nextcloud & Nextcloud + Media Server

If you chose between options 2 or 4 >> Nextcloud and Nextcloud + Media Server in the automated setup.sh script, or downloaded one of the Nextcloud or Nextcloud + Media Server folders, invoke the script like this:

### Nextcloud

   ```
   sudo ./Backup.sh 1
   ```
   Backup Nextcloud configurations, database, and data folder.
   ```
   sudo ./Backup.sh 2
   ```
   Backup Nextcloud configurations and database.
   ```
   sudo ./Backup.sh 3
   ```
   Backup Nextcloud configurations and database.

### Nextcloud + Media Server

Here, the commands described above remain the same:

   ```
   sudo ./Backup.sh 4
   ```
   Backup Nextcloud and Media Server settings.
   ```
   sudo ./Backup.sh 5
   ```
   Backup Nextcloud settings, database, and data folder, as well as Media Server settings.

### Restore

If you chose option 1 >> Backup Restore in the setup.sh automated script, or you cloned the entire repository to use and want to use the scripts contained in the repository root, run the script like this:
   ```
   sudo ./Restore.sh 2023-07-15
   ```

### Media Server

If you selected option 3 >> in the automated setup.sh script, or downloaded the Media Server folder, run the script as follows:
   ```
   sudo ./Restore.sh 2023-07-15
   ```

Nextcloud & Nextcloud + Media Server

If you chose between options 2 or 4 >> Nextcloud and Nextcloud + Media Server in the automated setup.sh script, or downloaded one of the Nextcloud or Nextcloud + Media Server folders, invoke the script like this:

### Nextcloud

   ```
   sudo ./Restore.sh 2023-07-15 1
   ```
   Restore Nextcloud configurations, database, and data folder.
   ```
   sudo ./Restore 2023-07-15 2
   ```
   Restore Nextcloud configurations and database.
   ```
   sudo ./Restore.sh 2023-07-15 3
   ```
   Restore Nextcloud configurations and database.

### Nextcloud + Media Server

Here, the commands described above remain the same:

   ```
   sudo ./Restore.sh 2023-07-15 4
   ```
   Restore Nextcloud and Media Server settings.
   ```
   sudo ./Restore.sh 2023-07-15 5
   ```
   Restore Nextcloud settings, database, and data folder, as well as Media Server settings.
```

This restructured README.md is well-organized, more concise, and easier to understand. Please remember to replace the URLs and paths with your own specific details as needed.