#!usr/bin/bash

#Vars

DIRGPG="/root/.gnupg"		# Diretório onde é armazenada chaves e senhas.
PASSFILE=/root/.config/backup/senha.txt			# Arquivo de Senha para Criptografar e descriptografar arquivos com GPG.
RCLONECONFIG="/home/usr/.config/rclone/rclone.conf.gpg"	# Arquivo criptografado rclone.conf.gpg
LOGFILE_PATH="/var/log/Borg/backup-$(date +%Y-%m-%d_%H-%M).txt"		# Arquivo de Log
RESTOREDIR=/home/

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO="/mnt/rclone/Onedrive/Backup/Borg"

# See the section "Passphrase notes" for more infos.
export BORG_PASSPHRASE='Senhasegura'

#gpg Descript

/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file '$PASSFILE' '$RCLONECONFIG' 

# Montar Remoto Rclone

sudo systemctl start Backup.service

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

# Restore the files from borg archive
# 
echo "Restoring Borg Archive"
cd /
borg extract -v --list "$BORG_REPO::$(hostname)-2022-05-16T21:40:05" '$RESTOREDIR' $LOGFILE_PATH

#RBackup Terminado 

sudo systemctl stop Backup.service

rm -rf /home/usr/.config/rclone/rclone.conf

echo
echo "DONE!"
echo "Successfully restored."

