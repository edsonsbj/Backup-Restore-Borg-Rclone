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

# Cria as pastas necessarias

mkdir /mnt/rclone/Borg /var/log/Rclone /var/log/Borg

# Monte o Rclone

sudo systemctl start Backup.service

# Restaura o backup do Nextcloud 
# 
echo "Restaurando backup das configurações do Nextcloud" >> $RESTLOGFILE_PATH

# Ativando Modo de Manutenção

echo
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --on >> $RESTLOGFILE_PATH
echo 

# Pare o Apache

systemctl stop apache2

# Remova a pasta atual do Nextcloud

rm -rf $NEXTCLOUD_CONF

# Extraia os Arquivos

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restaura o banco de dados 

echo "Restaurando banco de dados" >> $RESTLOGFILE_PATH

mysql -u --host=$HOSTNAME --user=$USER_NAME --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH

echo
echo "DONE!"

# Restaura a pasta ./data Nextcloud.
# Útil se a pasta ./data estiver fora de /var/www/nextcloud caso contrario recomendo comentar a linha abaixo, pois seu servidor já estará restaurado com o comando acima. 
# 
echo "Restaurando backup da pasta ./data" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

# Restaura as permissões 

chmod -R 770 $NEXTCLOUD_DATA 
chmod -R 755 $NEXTCLOUD_CONF
chown -R www-data:www-data $NEXTCLOUD_DATA
chown -R www-data:www-data $NEXTCLOUD_CONF

# Inicia o Apache

systemctl start apache2

# Desativando Modo de Manutenção Nextcloud

echo  
sudo -u www-data php $NEXTCLOUD_CONF/occ maintenance:mode --off >> $RESTLOGFILE_PATH
echo

echo
echo "DONE!"

# Restaura as configurações do Plex Media Server 

echo "Restaurando backup Plex" >> $RESTLOGFILE_PATH

# Pare o plex

sudo systemctl stop plexmediaserver

# Pare o plex (snap)

#sudo snap stop plexmediaserver

# Remova a Pasta atual do Emby

rm -rf $PLEX_CONF

# Extraia os arquivos

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $PLEX_CONF >> $RESTLOGFILE_PATH 2>&1

# Restaura as permissões

chmod -R 755 $PLEX_CONF
chown -R plex:plex $PLEX_CONF

# Restaura as permissões (snap)

#chmod -R 755 $PLEX_CONF
#chown -R root:root $PLEX_CONF

# Adicione o Usuário Emby ao grupo www-data para acessar as pastas do Nextcloud

sudo adduser plex www-data

# Adicione o Usuário Emby ao grupo www-data para acessar as pastas do Nextcloud (snap)

#sudo adduser root www-data

# Inicie o PLEX

sudo systemctl start plexmediaserver

# Inicia o Plex (snap)

#sudo snap start plexmediaserver

echo
echo "DONE!"

# Para sistemas de arquivos NTFS e FAT32 entre outros que não aceitam permissões convêm adicionar uma entrada em seu arquivo /etc/fstab para isso descomente a linha abaixo e altere o UUID /mnt/SEUHD e o campo ntfs-3g.
# Para encontrar o UUID de sua partição ou HD execute o comando sudo blkid. 

#cp /etc/fstab /etc/fstab.bk
#sudo cat <<EOF >>/etc/fstab
#UUID=089342544239044F /mnt/SEUHD ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
#EOF

echo
echo "DONE!"
echo "$(date "+%m-%d-%Y %T") : Successfully restored." 2>&1 | tee -a $RESTLOGFILE_PATH
