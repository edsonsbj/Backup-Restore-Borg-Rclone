#!/bin/bash

CONFIG="/path/to/.conf"
. $CONFIG

# Alguns auxiliares e tratamento de erros:
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

#
# Descomente as linhas a seguir se for preciso efetuar a restauração de arquivos ou pastas de armazenamento externo como pendrives e HD's Externos

# NÃO ALTERE
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1"

# O Dispositivo está Montado?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
  # Se não, monte em $MOUNTDIR
#  echo " Dispositivo não montado. Monte $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
#  # Se sim, grep o ponto de montagem e altere o $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Há permissões de excrita e gravação?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " Não tem permissões de gravação " >> $LOGFILE_PATH
#  exit 1
# }

info "Restauração Iniciada" 2>&1 | tee -a $RESTLOGFILE_PATH

# Mude para o diretório raiz. Isso é crítico pois o borg extract usa diretório relativo portanto devemos mudar para a raiz do sistema para que a restauração ocorra sem erros ou em diretórios aleatorios.

echo "Mudando para o diretório raiz..."
cd /
echo "pwd is $(pwd)"
echo "local do arquivo de backup db é " '/'

if [ $? -eq 0 ]; then
    echo "Done"
else
    echo "falha ao mudar para o diretório raiz. Falha na restauração"
    exit 1
fi

# Verifica se a data de restauração foi especificada
if [ -z "$ARCHIVE_DATE" ]
then
    echo "Por favor, especifique a data de restauração."
    exit 1
fi

# Encontra o nome do arquivo de backup correspondente à data especificada
ARCHIVE_NAME=$(borg list $BORG_REPO | grep $ARCHIVE_DATE | awk '{print $1}')

# Verifica se o arquivo de backup foi encontrado
if [ -z "$ARCHIVE_NAME" ]
then
    echo "Não foi possível encontrar um arquivo de backup para a data especificada: $ARCHIVE_DATE"
    exit 1
fi

# Função para mensagens de erro
errorecho() { cat <<< "$@" 1>&2; } 

# Caso tenha criptografado seu arquivo rclone.conf com GPG conforme instruções contidas no README, descomente as linhas a seguir

#/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file $PASSFILE $RCLONECONFIG_CRIPT >> $RESTLOGFILE_PATH 2>&1

# Monte o Rclone

sudo systemctl start Backup.service

# Ativando Modo de Manutenção

echo
sudo nextcloud.occ maintenance:mode --on >> $RESTLOGFILE_PATH
echo

# Extraia os arquivos 
# 
echo "Restaurando Arquivos " $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME --patterns-from $PATTERNS >> $RESTLOGFILE_PATH 2>&1

# Desativando Modo de Manutenção Nextcloud

echo  
sudo nextcloud.occ maintenance:mode --off >> $RESTLOGFILE_PATH
echo

# Restaurando Configurações Nextcloud 

sudo nextcloud.import -abc $NEXTCLOUD_CONFIG >> $RESTLOGFILE_PATH

# Caso tenha criptografado seu arquivo rclone.conf com GPG é recomendável excluir o arquivo descriptografado apos a Restauração. 
# Para isso descomente a linha a seguir.

#rm -rf $RCLONECONFIG >> $RESTLOGFILE_PATH 2>&1 

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $RESTLOGFILE_PATH
