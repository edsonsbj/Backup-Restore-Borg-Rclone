#!/bin/bash

# Variáveis

DIRGPG='/path/to/.gnupg'					# Diretório onde é armazenada chaves e senhas.
PASSFILE='/path/to/senha.txt'					# Arquivo contendo a senha GPG 
RCLONECONFIG_CRIPT='/path/to/rclone.conf.gpg'			# Arquivo criptografado rclone.conf.gpg
RCLONECONFIG='/path/to/rclone.conf'				# Arquivo descriptografado 
LOGFILE_PATH='/path/to/backup-$(date +%Y-%m-%d_%H-%M).txt'	# Arquivo de Log
RESTOREDIR='/path/to/folder'					# Diretório a ser restaurado
DATARESTORE=2022-04-16T21:40:05				# Data do backup a ser restaurado (borg list)

# Configurando isso, para que o repositório não precise ser fornecido na linha de comando:
export BORG_REPO="/path/to/folder/Repo"

# Configurando isso, para que a senha não seja fornecido na linha de comando 
export BORG_PASSPHRASE='Senhasegura'

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
