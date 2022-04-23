#!/bin/bash

CONFIG="/path/to/Configs"
. $CONFIG

# Alguns auxiliares e tratamento de erros:
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

info "Restauração Iniciada" 2>&1 | tee -a $LOGFILE_PATH

# Função para mensagens de erro
errorecho() { cat <<< "$@" 1>&2; } 

#gpg Descript

/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file $PASSFILE $RCLONECONFIG_CRIPT >> $LOGFILE_PATH 2>&1

# Montar Remoto Rclone

sudo systemctl start Backup.service

# Restaura os Arquivos 
# 
echo "Restoring Borg Archive" $LOGFILE_PATH
cd /
borg extract -v --list "$BORG_REPO::$(hostname)-$DATARESTORE" $RESTOREDIR >> $LOGFILE_PATH 2>&1

# Backup Terminado 

sudo systemctl stop Backup.service

rm -rf $RCLONECONFIG >> $LOGFILE_PATH 2>&1 

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $LOGFILE_PATH
