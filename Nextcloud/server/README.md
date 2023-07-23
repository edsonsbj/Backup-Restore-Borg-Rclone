# Nextcloud server

Este diretório contém um script que realiza o backup e a restauração de sua instância Nextcloud, incluindo a pasta de dados. O backup é feito usando o Borg Backup e a montagem Rclone para armazenar seus backups em um serviço de nuvem de sua escolha.

## Início

- Certifique-se de que o `Nextcloud` já está instalado e funcionando corretamente.
- Verifique se os programas `rclone`, `borg` e `git` já estão instalados em seu sistema.
- Clone este repositório usando o comando `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.

## Backup

1. Faça uma cópia do arquivo `example.conf` e renomeie-o de acordo com suas necessidades.
2. Adicione as pastas que deseja fazer backup no arquivo `patterns.lst`. Por padrão, o arquivo já está pré-configurado para fazer backup das pastas do `Nextcloud`, incluindo a pasta de dados, excluindo a lixeira.
3. Defina as variáveis no arquivo `.conf` para corresponder às suas necessidades.
4. Opcionalmente, mova os arquivos `backup.sh`, `patterns.lst`, `restore.sh` e o arquivo `.conf` recém-editado para uma pasta de sua preferência.
5. Torne os scripts executáveis usando o comando `sudo chmod +x`.
6. Substitua os valores `--config=/path/user/rclone.conf` e `Borg:`/ no arquivo `Backup.service` pelas configurações apropriadas, onde `--config` corresponde ao local do seu arquivo `rclone.conf` e `Borg:/` corresponde ao seu remoto (nuvem) a ser montado.
7. Mova o `Backup.service` para a pasta `/etc/systemd/system/`.
8. Execute o script `./backup.sh` ou crie um novo trabalho no Cron usando o comando `crontab -e`, conforme exemplo abaixo:

```
00 00 * * * sudo ./backup.sh
```

## Restauração

Opções de restauração:

### Restaure todo o servidor

Restaura todos os arquivos.

- Execute o script com a data desejada do backup a ser restaurado.

```
./restore.sh 2023-07-15
```

### Restaure Nextcloud/data

Para restaurar somente a pasta ./data, siga as instruções abaixo.

- Em seu arquivo `restore.sh`, comente o intervalo de linhas abaixo.

```
# Restaura o backup do Nextcloud

echo "Restaurando backup das configurações do Nextcloud" >> $RESTLOGFILE_PATH

borg extract -v --list $BORG_REPO::$ARCHIVE_NAME $NEXTCLOUD_CONF >> $RESTLOGFILE_PATH 2>&1

echo
echo "DONE!"

Restaura o banco de dados

echo "Restaurando banco de dados" >> $RESTLOGFILE_PATH

mysql -u --host=$HOSTNAME --user=$USER_NAME --password=$PASSWORD $DATABASE_NAME < "$NEXTCLOUD_CONF/nextclouddb.sql" >> $RESTLOGFILE_PATH

echo
echo "DONE!"
```

- Execute o script com a data desejada do backup a ser restaurado.

```
./restore.sh 2023-07-15
```

### Restaure os dados em mídia removível

- Altere as variáveis `DEVICE` e `MOUNTDIR` `NEXTCLOUD_DATA` em seu arquivo `.conf`.
- Em seu arquivo `restore.sh`, descomente as linhas a seguir.

```
# NÃO ALTERE
# MOUNT_FILE="/proc/mounts"
# NULL_DEVICE="1> /dev/null 2>&1"
# REDIRECT_LOG_FILE="1>> $LOGFILE_PATH 2>&1"

# O dispositivo está montado?
# grep -q "$DEVICE" "$MOUNT_FILE"
# if [ "$?" != "0" ]; then
# Se não, monte em $MOUNTDIR
#  echo " Dispositivo não montado. Montando $DEVICE " >> $LOGFILE_PATH
#  eval mount -t auto "$DEVICE" "$MOUNTDIR" "$NULL_DEVICE"
#else
# Se sim, grep o ponto de montagem e altere o $MOUNTDIR
#  DESTINATIONDIR=$(grep "$DEVICE" "$MOUNT_FILE" | cut -d " " -f 2)
#fi

# Há permissões de escrita e gravação?
# [ ! -w "$MOUNTDIR" ] && {
#  echo " Não tem permissões de gravação " >> $LOGFILE_PATH
#  exit 1
#}
```

### Para partições e mídias em formato NTFS exFAT e FAT32

1. Adicione a seguinte entrada no arquivo `/etc/fstab`:

```
UUID=089342544239044F /mnt/Multimidia ntfs-3g utf8,uid=www-data,gid=www-data,umask=0007,noatime,x-gvfs-show 0 0
```

2. Altere o `UUID` para corresponder ao `UUID` da unidade que será montada. Para encontrar o `UUID` correto, execute o comando `sudo blkid`.
3. Altere `/mnt/Multimidia` para o ponto de montagem de sua preferência. Se o ponto de montagem não existir, crie-o usando o comando `sudo mkdir /mnt/seu_pontodemontagem`.
4. Altere `ntfs-3g` para o formato de partição desejado, como exFAT ou FAT32.
5. Execute o comando `sudo mount -a` para montar a unidade.
6. Se ocorrer algum erro ao executar o comando acima, instale os pacotes `ntfs-3g` para partições `NTFS` ou `exfat-fuse` e `exfat-utils` para partições `exFAT`.

## Algumas observações importantes

- É altamente recomendável desmontar a unidade local onde foi efetuado o backup após a conclusão do processo. Para isso, crie um agendamento no Cron para desmontar a unidade em um intervalo de 3 horas após o início do backup. Por exemplo:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

Isso garantirá que o Rclone tenha tempo suficiente para completar o upload dos arquivos para a nuvem antes de desmontar a unidade.

## Testes

Em testes realizados, o tempo decorrido para o backup e restauração foi semelhante ao de outras ferramentas como `Duplicity` ou `Deja-Dup`.
