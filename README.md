# Scripts de Backup e Restauração usando Borg Backup e Rclone

Este repositório contém scripts para realização de backup e restauração utilizando as ferramentas Borg e Rclone. O Rclone é usado para montar um serviço de nuvem de sua preferência em uma unidade local, permitindo a realização de backups e restaurações. 

## Início

- Verifique se os programas `rclone`, `borg` e `git` já estão instalados em seu sistema.
- Clone este repositório usando o comando `git clone https://github.com/edsonsbj/Backup-Restore-Borg-Rclone.git`.


## Backup

1. Faça uma cópia do arquivo `example.conf` e renomeie-o de acordo com suas necessidades.
2. Adicione as pastas que deseja fazer backup no arquivo `patterns.lst`.
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

Restaura todos os arquivos.

- Execute o script com a data desejada do backup a ser restaurado juntamente com o arquivo ou diretorio que gostaria de restaurar.

```
./restore.sh 2023-07-15 home/
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

## Algumas observações importantes

- É altamente recomendável desmontar a unidade local onde foi efetuado o backup após a conclusão do processo. Para isso, crie um agendamento no Cron para desmontar a unidade em um intervalo de 3 horas após o início do backup. Por exemplo:

```
00 00 * * * sudo ./backup.sh
00 03 * * * sudo systemctl stop backup.service
```

Isso garantirá que o Rclone tenha tempo suficiente para completar o upload dos arquivos para a nuvem antes de desmontar a unidade.

## Testes

Em testes realizados, o tempo decorrido para o backup e restauração foi semelhante ao de outras ferramentas como `Duplicity` ou `Deja-Dup`.


## Nextcloud
Neste diretório, você encontrará dois scripts para realizar o backup e a restauração do Nextcloud, dependendo do tipo de instalação que você fez: manual (Apache + MySQL + PHP) ou por meio de pacotes snap.

### Nextcloud + Plex
Use este script se você tiver um servidor Nextcloud e Plex na mesma máquina. Dentro da pasta, há duas opções de script, uma para cada tipo de instalação do Nextcloud.

### Nextcloud + Emby (Jellyfin)
Use este script se você tiver um servidor Nextcloud e Emby na mesma máquina. Dentro da pasta, há duas opções de script, uma para cada tipo de instalação do Nextcloud. Além disso, é possível alterar o script caso você utilize o Jellyfin em vez do Emby.

