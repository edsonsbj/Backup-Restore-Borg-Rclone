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

# Verifica se a data de restauração e o arquivo a ser restaurado foram especificados
if [ -z "$ARCHIVE_DATE" ] || [ -z "$FILE_TO_RESTORE" ]
then
    echo "Por favor, especifique a data de restauração e o arquivo a ser restaurado como primeiro e segundo argumentos, respectivamente."
    exit 1
fi

# Encontra o nome do arquivo de backup correspondente à data especificada
ARCHIVE_NAME=$(borg list $REPOSITORY | grep $ARCHIVE_DATE | awk '{print $1}')

# Verifica se o arquivo de backup foi encontrado
if [ -z "$ARCHIVE_NAME" ]
then
    echo "Não foi possível encontrar um arquivo de backup para a data especificada: $ARCHIVE_DATE"
    exit 1
fi

# Restaura o arquivo especificado a partir do backup
borg extract --list $REPOSITORY::$ARCHIVE_NAME $FILE_TO_RESTORE

# Função para mensagens de erro
errorecho() { cat <<< "$@" 1>&2; } 

# Cria as pastas necessarias

mkdir /mnt/rclone/Borg /var/log/Rclone /var/log/Borg

# Monte o Rclone

sudo systemctl start Backup.service

# Restaura o backup
# 
echo "Restaurando backup" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $FILE_TO_RESTORE >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $RESTLOGFILE_PATH
