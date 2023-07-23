#!/bin/bash

CONFIG="/path/to/.conf"
. $CONFIG

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

#
# Check if Script is run by root
#
if [ "$(id -u)" != "0" ]
then
        errorecho "ERROR: This script must be run as root!"
        exit 1
fi

info "Backup Started" 2>&1 | tee -a $LOGFILE_PATH

# Create Necessary Folders

mkdir /mnt/rclone /var/log/Rclone /var/log/Borg

# Mount Rclone

sudo systemctl start Backup.service

# Export Nextcloud Configurations

sudo nextcloud.export -abc >> $LOGFILE_PATH

sudo tar -cvf $BACKUP_FILE $NEXTCLOUD_CONF

# Enabling Maintenance Mode

echo
sudo nextcloud.occ maintenance:mode --on >> $LOGFILE_PATH
echo

# Backup the most important directories into an archive named after
# the machine this script is being executed on

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --progress                      \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --exclude-caches                \
    --patterns-from $PATTERNS	    \
    >> $LOGFILE_PATH 2>&1	    \
    ::'{hostname}-{now:%Y%m%d-%H%M}'            \

backup_exit=$?

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of this machine. The '{hostname}-' prefix is very important to
# limit prune's operation to this machine's archives and not apply to
# other machines' archives also:

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6               \
    >> $LOGFILE_PATH 2>&1

prune_exit=$?

# Disabling Nextcloud Maintenance Mode

echo  
sudo nextcloud.occ maintenance:mode --off >> $LOGFILE_PATH
echo

rm -rf $NEXTCLOUD_CONF/

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a $LOGFILE_PATH
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a $LOGFILE_PATH
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a $LOGFILE_PATH
fi

exit ${global_exit}

echo
echo "DONE!"
echo "Backup Completed." $LOGFILE_PATH
