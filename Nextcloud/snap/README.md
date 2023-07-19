# **Nextcloud**

Este Script realiza o Backup e a Restauração de sua instância Nextcloud instalada por meio de pacotes snap, assim como sua pasta de dados que geralmente é armazenada em `/data`. Utilizando a Ferramenta de Backup Borg que por sua vez cria um repositorio remoto em um serviço de nuvem de sua preferencia utilizando uma montagem Rclone.

## **Vamos Começar**

 - Verifique se ja possui o nextcloud instalado e funcionando.
 - Verifique se os programas `rclone`, `borg` e `git ja estão instalados 
 - Clone este repositório `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git.` 

## **Backup**

  - Faça uma copia do arquivo `example.conf` e o renomeie.
  - Adicione as pastas para fazer backup no arquivo `patterns.lst`. Por Padrão o arquivo já esta pré-configurado para fazer backup das pastas `/var/snap/nextcloud/common/backups` `/path/nextcloud/data` e excluir do backup a pasta `./files_trashbin`.
  - Defina as variáveis em seu arquivo `.conf`, para que corresponda as suas necessidades.
  - Opicionalmente mova os arquivos `backup.sh`, `patterns.lst`, `restore.sh` e o arquivo recem editado `.conf` para uma pasta de sua preferência.
  - Torne os scripts executáveis `sudo chmod +x`.
  - Altere as variáveis `AssertPathIsDirectory --config --cache-info-age=60m e ExecStop=/bin/fusermount -u` no arquivo `Backup.service`.
  - Mova o `Backup.service` para a pasta `/etc/systemd/system`.
  - Execute o Script `./backup.sh`, ou crie um novo trabalho no Cron `crontab -e` conforme exemplo abaixo para que seu backup .

 ````
 00 00 * * * sudo ./backup.sh
 ````

## **Restauração**

Aqui temos alguns tipos de restauração.

**Restauração completa**

  - Execute o script com a data desejada do backup a ser restaurado.

   ```
   ./restore.sh 2023-07-15
   ```

**Restauração das Configurações**

  - Em seu arquivo `restore.sh` comente o intervalo de linhas abaixo.

 ```
 # Restaura a pasta ./data Nextcloud.
 # Útil se a pasta ./data estiver fora de /var/www/nextcloud caso contrario recomendo comentar a linha abaixo, pois seu servidor já estará restaurado com o comando acima. 
 # 
 echo "Restaurando backup da pasta ./data" >> $RESTLOGFILE_PATH

 borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_DATA >> $RESTLOGFILE_PATH 2>&1

 echo
 echo "DONE!"
 ```

**Restauração dos dados**

  - Em seu arquivo `restore.sh` comente o intervalo de linhas abaixo. 

 ```
 # Restaura as configurações do Nextcloud 
 # 
 echo "Restaurando backup das configurações do Nextcloud" >> $RESTLOGFILE_PATH

 borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

 # Verifique se o arquivo de backup existe
 if [ -z "RESTORE_FILE" ]; then
     echo "Nenhum arquivo de backup encontrado"
     exit 1
 fi

  sudo nextcloud.import -abc $RESTORE_FILE >> $RESTLOGFILE_PATH

 echo
 echo "DONE!"
 ```

  - Execute o script com a data desejada do backup a ser restaurado.

   ```
   ./restore.sh 2023-07-15
   ```

**Restaurando os dados em outras partições ou HD**

  - Altere as variáveis `DEVICE` e `MOUNTDIR` `NEXTCLOUD_DATA` em seu arquivo `.conf`.
  - Em seu arquivo `restore.sh` descomente as linhas a seguir. 
 ```
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
 # Se sim, grep o ponto de montagem e altere o $MOUNTDIR
 #  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
 #fi

 # Há permissões de excrita e gravação?
 # [ ! -w "$MOUNTDIR" ] && {
 #  echo " Não tem permissões de gravação " >> $LOGFILE_PATH
 #  exit 1
 # }
 ```
 
  - Execute o script com a data desejada do backup a ser restaurado.
  ```
  ./restore.sh 2023-07-15
  ```

**Restaurando os dados em partições NTFS exFAT e FAT32**

  - Altere as variáveis `DEVICE` e `MOUNTDIR` `NEXTCLOUD_DATA` em seu arquivo `.conf`.
  - Adicione a seguinte entrada no arquivo `/etc/fstab`

 ```
 UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
 ```
  - Altere o `UUID` para o que sera obitido atraves do comando `sudo blkid`.
  - Altere `/mnt/Multimidia` para o ponto de montagem de sua preferência. Lembrando que se o ponto de montagem não existir, favor cria-lo com o comando `sudo mkdir /mnt/seu_pontodemontagem`.
  - Altere `ntfs-3g` para o formato de partição desejado como exFAT ou FAT32.
  - Execute o comando `sudo mount -a`
  - Caso ocorra algum erro ao executar o comando acima primeiro verifique se o ponto de montagem existe, caso o mesmo não exista execute o comando `mkdir /mnt/MeuArmazenamento` ou `/media/edson/MeuArmazenamento` e tente executar o comando acima novamente se o erro persistir recomendo que instale os pacotes `ntfs-3g` para partições `NTFS` ou `exfat-fuse e exfat-utils` para partições `exfat`
  - Em seu arquivo `restore.sh` descomente as linhas a seguir.
 
 ```
 # NÃO ALTERE
 # MOUNT_FILE="/proc/mounts"
 # NULL_DEVICE="1> /dev/null 2>&1"
 # REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1" 

 # O Dispositivo está Montado?
 # grep -q "$DEVICE" "$MOUNT_FILE"
 # if [ "$?" != "0" ]; then
 # Se não, monte em $MOUNTDIR
 # echo " Dispositivo não montado. Monte $DEVICE " >> $LOGFILE_PATH
 # eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
 # else
 # Se sim, grep o ponto de montagem e altere o $MOUNTDIR
 # DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
 # fi

 # Há permissões de excrita e gravação?
 # [ ! -w "$MOUNTDIR" ] && {
 # echo " Não tem permissões de gravação " >> $LOGFILE_PATH
 # exit 1
 # }
 ```

  - Execute o script com a data desejada do backup a ser restaurado.

  ```
  ./restore.sh 2023-07-15
  ```

 ### Algumas Observações Importantes 

  - Recomendo fortemente que efetue a desmontagem da unidade local onde foi efetuado o backup, para isso crie um agendamento no cron para que a unidade seja desmontada em um intervalo de 3 horas após início do backup.  
  ````
  00 00 * * * sudo ./backup.sh
  00 03 * * * sudo systemctl stop backup.service
  ````
No meu caso o backup demora entre 1 e 2 horas aí deixo sempre um intervalo para que o rclone consigo completar o upload corretamente dos arquivos para a nuvem. 

### Testes

  - Em testes realizados o tempo decorrido do backup e restauração foram semelhantes ao de outras ferramentas como `duplicity ou deja-dup.`
