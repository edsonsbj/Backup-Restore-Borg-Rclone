# **Nextcloud**

Este Script realiza o Backup e a Restauração de sua instância Nextcloud instalada manualmente com LAMP server, assim como sua pasta de dados que geralmente é armazenada em `/var/www/nextcloud/data`.

## **Realizando Backup**

 1. Certifique-se de que o Nextcloud ja esteja rodando sem nenhum erro.
 2. Certifique-se de que os pacotes `rclone` e  `borg `estejam instalados. 
 3. Opicionalmente crie e criptografe seu arquivo `rclone.conf` com o comando
 ````
 sudo gpg --batch --no-tty --homedir /path/to/.gnupg --passphrase-file '/path/to/senha.txt' -c /path/to/rclone.conf.
 ````
 4. Faça uma copia do arquivo `example.conf` e o renomeie.
 5. Se preferir adicione as pastas para fazer backup no arquivo `patterns.lst`. Por Padrão o arquivo já esta pré-configurado para fazer backup das pastas `/var/www/nextcloud` `/path/nextcloud/data` e excluir do backup a pasta `./files_trashbin`.
 6. Defina as variáveis em seu arquivo `.conf`, para que corresponda as suas necessidades.
 7. Se Preferir mova os arquivos `backup.sh`, `patterns.lst`, `restore.sh` e o arquivo recem editado `.conf` para uma pasta de sua preferência.
 8. Torne os scripts executáveis `sudo chmod a+x`.
 9. Altere as variáveis `AssertPathIsDirectory --config --cache-info-age=60m e ExecStop=/bin/fusermount -u` no arquivo `Backup.service`.
 10. Mova o `Backup.service` para a pasta `/etc/systemd/system`.
 11. Execute o script `backup.sh`ou agende o mesmo no Cron 
 ````
 00 00 * * * sudo /path/to/backup.sh
 ```` 

## **Integridade e Segurança do Backup & Restauração**

 12. Este Conjunto de Scripts ele monta o seu serviço de nuvem como uma unidade local portanto para ter uma segurança melhor e não ter nenhum risco de perda de dados recomendo que efetue um agendamento no cron para que apos o backup ou a restauração a unidade seja desmontada do sistema e caso tenha optado pela criptografia do rclone.conf com gpg seja removido o arquivo descriptografado no inicio do backup.
Exemplo:
 ````
 00 00 * * * sudo /path/to/backup.sh 						# Efetua o Backup
 00 2 * * * systemctl stop Backup.service | rm -rf /path/to/rclone.conf		# Desliga a Nuvem e remove o arquivo descritografado
 ```` 

## **Restauração**

**Restaure todo o Servidor**


 1. Execute o script com a data desejada do backup a ser restaurado.

    Exemplo
   ```
   ./restore.sh 2023-07-15
   ```
 2. Caso queira restaurar a pasta `./Nextcloud/data` em um HD Externo, altere as variáveis `DEVICE` e `MOUNTDIR` em seu arquivo `.conf`, e descomente as linhas a seguir no arquivo `restore.sh:` 
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
#  # Se sim, grep o ponto de montagem e altere o $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Há permissões de excrita e gravação?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " Não tem permissões de gravação " >> $LOGFILE_PATH
#  exit 1
# }
```
**Restaure os dados**

1. Em seu arquivo `restore.sh` comente o intervalo de linhas 94 a 111. 

Exemplo
```
# Restaura o backup do Nextcloud 
# 
#echo "Restaurando backup das configurações do Nextcloud" >> $RESTLOGFILE_PATH
#
#borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1
#
#echo
#echo "DONE!"
#
# Restaura o banco de dados 
#
#echo "Restaurando banco de dados" >> $RESTLOGFILE_PATH
#
#mysql -u --host=$HOSTNAME --user=$USER_NAME --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH
#
#echo
#echo "DONE!"
```

2. Execute o script com a data desejada do backup a ser restaurado.

    Exemplo
   ```
   ./restore.sh 2023-07-15
   ```
3. Caso a pasta `./Nextcloud/data` esteja armazenada em um HD Externo, altere as variáveis `DEVICE` e `MOUNTDIR` `NEXTCLOUD_DATA` em seu arquivo `.conf`, e descomente as linhas a seguir no arquivo `restore.sh:` 
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
#  # Se sim, grep o ponto de montagem e altere o $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Há permissões de excrita e gravação?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " Não tem permissões de gravação " >> $LOGFILE_PATH
#  exit 1
# }
```

### Algumas Observações Importantes 

   - A Criptografia do arquivo `rclone.conf` é opcional, caso não tenha interesse descomente as linhas referente a gpg tanto no arquivo `backup.sh e restore.sh.`
 ```
/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file $PASSFILE $RCLONECONFIG_CRIPT >> $RESTLOGFILE_PATH 2>&1
```
   - Recomendo fortemente que efetue a desmontagem da sua nuvem remota onde foi feito o backup para isso agende no cron para que isso ocorra de uma forma automatica
 ````
 00 00 * * * sudo /path/to/backup.sh
 00 04 * * * sudo systemctl stop backup.service
 ````
Ou caso tenha criptografado o rclone.conf com GPG
 ````
 00 00 * * * sudo /path/to/backup.sh
 00 04 * * * sudo systemctl stop backup.service | rm -rf /path/to/rclone.conf
 ````
### Testes

 - Em testes realizados o tempo decorrido do backup e restauração foram semelhantes ao de outras ferramentas como `duplicity ou deja-dup.`

 