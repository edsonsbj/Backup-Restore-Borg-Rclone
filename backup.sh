#!/bin/bash

#Vars

DIRGPG='/root/.gnupg'		# Diretório onde é armazenada chaves e senhas.
PASSFILE='/root/.config/backup/senha.txt'	# Arquivo de Senha para Criptografar e descriptografar arquivos com GPG.
RCLONECONFIG_CRIPT='/home/edson/.config/rclone/rclone-backup.conf.gpg'	# Arquivo criptografado rclone.conf.gpg
RCLONECONFIG="/home/edson/.config/rclone/rclone-backup.conf"		# Arquivo descriptografado 
LOGFILE_PATH="/var/log/Borg/restore-$(date +%Y-%m-%d_%H-%M).txt"	# Arquivo de Log
BACKUPDIR="/mnt/Nextcloud/data"

# Configurando isso, para que o repositório não precise ser fornecido na linha de comando:
export BORG_REPO="/mnt/rclone/Onedrive/Backup/Borg/Nextcloud"

# Configurando isso, para que a senha não seja fornecido na linha de comando 
export BORG_PASSPHRASE='d76omCmT7SD@m@9@'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

#
# Verifica se o Script é executado pelo root
#
if [ "$(id -u)" != "0" ]
then
        errorecho "ERRO: Este script deve ser executado como root!"
        exit 1
fi

info "Backup Iniciado" 2>&1 | tee -a $LOGFILE_PATH

#gpg Descript

/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file $PASSFILE $RCLONECONFIG_CRIPT >> $LOGFILE_PATH 2>&1


sudo systemctl start Multimidia2.service

# Faça backup dos diretórios mais importantes em um arquivo com o nome
# a máquina em que este script está sendo executado

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
    --exclude-from '/home/edson/Documentos/Scripts Borg/borg-rclone-backup/excludes.txt'  \
                                    \
    ::'{hostname}-{now}'            \
    $BACKUPDIR             \
    >> $LOGFILE_PATH 2>&1


backup_exit=$?

info "Pruning repository"

# Use o subcomando `prune` para manter 7 dias, 4 semanais e 6 mensais
# arquivos desta máquina. O prefixo '{hostname}-' é muito importante para
# limita a operação do prune aos arquivos desta máquina e não se aplica a
# arquivos de outras máquinas também:	

borg prune                          \
    --list                          \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6               \
    >> $LOGFILE_PATH 2>&1

prune_exit=$?

# usa o código de saída mais alto como código de saída global
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune finished successfully" 2>&1 | tee -a $LOGFILE_PATH
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune finished with warnings" 2>&1 | tee -a $LOGFILE_PATH
else
    info "Backup, Prune finished with errors" 2>&1 | tee -a $LOGFILE_PATH
fi

exit ${global_exit}

# Backup Concluido 

sudo systemctl stop Multimidia2.service

rm -rf '$RCLONECONFIG' 

echo
echo "DONE!"
echo "Backup Concluido." $LOGFILE_PATH
