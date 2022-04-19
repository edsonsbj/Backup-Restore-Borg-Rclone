#!usr/bin/bash

#gpg Descript
/usr/bin/gpg --batch --no-tty --homedir /root/.gnupg --passphrase-file '/root/.config/backup/senha.txt' '/home/usr/.config/rclone/rclone.conf.gpg'

sudo systemctl start Backup.service

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO="/mnt/rclone/Onedrive/Backup/Borg"

# See the section "Passphrase notes" for more infos.
export BORG_PASSPHRASE='Senhasegura'

#Vars

LOGFILE_PATH="/var/log/Borg/backup-$(date +%Y-%m-%d_%H-%M).txt"

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info "Starting backup" 2>&1 | tee -a $LOGFILE_PATH

# Backup the most important directories into an archive named after
# the machine this script is currently running on:

#echo "$(date "+%m-%d-%Y %T") : Borg backup has started" 2>&1 | tee -a $LOGFILE_PATH
borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --progress                      \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    --exclude-caches                \
    --exclude-from '/home/user/Documentos/excludes.txt'  \
                                    \
    ::'{hostname}-{now}'            \
    /home/             \
    >> $LOGFILE_PATH 2>&1


backup_exit=$?

info "Pruning repository"

# Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
# archives of THIS machine. The '{hostname}-' prefix is very important to
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

#RBackup Terminado 

sudo systemctl start Backup.service

rm -rf /home/edson/.config/rclone/rclone-backup.conf
