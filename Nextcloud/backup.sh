#!/bin/bash

CONFIG="/path/to/.conf"
. $CONFIG

# alguns ajudantes e tratamento de erros:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrompido >&2; exit 2' INT TERM

#
# Verifica se o Script é executado pelo root
#
if [ "$(id -u)" != "0" ]
then
        errorecho "ERRO: Este script deve ser executado como root!"
        exit 1
fi

info "Backup Iniciado" 2>&1 | tee -a $LOGFILE_PATH

# Caso tenha criptografado o arquivo rclone.conf com GPG descomente a linha abaixo.

# /usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file $PASSFILE $RCLONECONFIG_CRIPT >> $LOGFILE_PATH 2>&1

# Monte o Rclone

sudo systemctl start Backup.service

# Ativando Modo de Manutenção

echo
sudo -u www-data php $NEXTCLOUDCONF/occ maintenance:mode --on >> $LOGFILE_PATH
echo

# Exporte o Banco de dados

mysqldump --quick -n --host=$HOSTNAME $DATABASE_NAME --user=$USER_NAME --password=$PASSWORD > $NEXTCLOUD_DB

# Faça backup dos diretórios mais importantes em um arquivo com o nome
# a máquina em que este script está sendo executado

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

# Desativando Modo de Manutenção Nextcloud

echo  
sudo -u www-data php $NEXTCLOUDCONF/occ maintenance:mode --off >> $LOGFILE_PATH
echo

# Desmonte o Rclone

# sudo systemctl stop Backup.service

# Descomente a linha abaixo caso tenha criptografado o arquivo rclone.conf com GPG para que o script remova o arquivo descriptografado. 
# rm -rf $RCLONECONFIG 

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

echo
echo "DONE!"
echo "Backup Concluido." $LOGFILE_PATH
