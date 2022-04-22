#!/bin/bash

#Vars

DIRGPG='/root/.gnupg'		# Diretório onde é armazenada chaves e senhas.
PASSFILE='/root/.config/backup/senha.txt'	# Arquivo de Senha para Criptografar e descriptografar arquivos com GPG.
RCLONECONFIG_CRIPT='/home/edson/.config/rclone/rclone-backup.conf.gpg'	# Arquivo criptografado rclone.conf.gpg
RCLONECONFIG="/home/edson/.config/rclone/rclone-backup.conf"		# Arquivo descriptografado 
LOGFILE_PATH="/var/log/Borg/restore-$(date +%Y-%m-%d_%H-%M).txt"	# Arquivo de Log
DATARESTORE=2022-04-16T21:40:05		# Data do backup a ser restaurado (borg list)
RESTOREDIR="/mnt/Nextcloud/data/Lucao"		# Arquivo ou Diretório a ser Resrtaurado

# Configurando isso, para que o repositório não precise ser fornecido na linha de comando:
export BORG_REPO="/mnt/rclone/Onedrive/Backup/Borg/Nextcloud"

# Configurando isso, para que a senha não seja fornecido na linha de comando 
export BORG_PASSPHRASE='d76omCmT7SD@m@9@'

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

sudo systemctl start Multimidia2.service

# Restaura os Arquivos 
# 
echo "Restoring Borg Archive" $LOGFILE_PATH
cd /
borg extract -v --list "$BORG_REPO::$(hostname)-$DATARESTORE" $RESTOREDIR >> $LOGFILE_PATH 2>&1

# Backup Terminado 

sudo systemctl stop Multimidia2.service

rm -rf $RCLONECONFIG >> $LOGFILE_PATH 2>&1 

echo
echo "DONE!"
echo "Successfully restored." >> $LOGFILE_PATH 2>&1

