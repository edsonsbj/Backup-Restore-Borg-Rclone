# **Conjunto de Scripts para realizar backup e restauração usando Borg Backup e rclone**

Este conjunto reune scripts básicos para realizar backups automáticos usando Borg Backup e rclone. Ele usa um serviço systemd para montar um remoto rclone em uma pasta especifica como `/mnt/`.

## **Realizando Backup**

 1. Certifique-se de que os pacotes `rclone` e  `borg `estejam instalados. 
  2. Opicionalmente crie e criptografe seu arquivo `rclone.conf` com o comando
 ````
 sudo gpg --batch --no-tty --homedir /path/to/.gnupg --passphrase-file '/path/to/senha.txt' -c /path/to/rclone.conf.
 ````
 3. Faça uma copia do arquivo `example.conf` e o renomeie.
 4. Se preferir adicione as pastas para fazer backup no arquivo `patterns.lst`.
 5. Defina as variáveis em seu arquivo `.conf`, para que corresponda as suas necessidades.
 6. Se Preferir mova os arquivos `backup.sh`, `patterns.lst`, `restore.sh` e o arquivo recem editado `.conf` para uma pasta de sua preferência.
 7. Torne os scripts executáveis `sudo chmod a+x`.
 8. Altere as variáveis `AssertPathIsDirectory --config --cache-info-age=60m e ExecStop=/bin/fusermount -u` no arquivo `Backup.service`.
 9. Mova o `Backup.service` para a pasta `/etc/systemd/system`.
  10. Execute o script `backup.sh`ou agende o mesmo no Cron 
 ````
 00 00 * * * sudo /path/to/backup.sh
 ```` 
## **Restauração**

1. Execute o comando `sudo borg list /path-to-your-repo.`
2. Anote ou copie a data do backup que deseja restaurar 
3. Informe a data na variável `DATARESTORE` em seu arquivo `.conf`
4. Altere o caminho na variável `NEXTCLOUD_CONFIG` em seu arquivo `.conf` para que corresponda ao caminho exato onde o Nextcloud despejou as configurações exportadas. Geralmente `/var/snap/nextcloud/common/backups/20220430-200029`.
5. Execute o script `restore.sh` ou agende o mesmo no cron.
6. Caso queira restaurar uma determinada pasta em um HD Externo, altere as variáveis `DEVICE` e `MOUNTDIR` em seu arquivo `.conf`,  e descomente as linhas a seguir no arquivo `restore.sh:` 
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

   - A Criptografia do arquivo `rclone.conf` é opcional, caso não tenha interesse comente as linhas referente a gpg tanto no arquivo `backup.sh e restore.sh.`
  ```
 #gpg Descript

/usr/bin/gpg --batch --no-tty --homedir $DIRGPG --passphrase-file $PASSFILE $RCLONECONFIG_CRIPT >> $RESTLOGFILE_PATH 2>&1
```
### Testes

 - Em testes realizados o tempo decorrido do backup e restauração foram semelhantes ao de outras ferramentas como `duplicity ou deja-dup.`
