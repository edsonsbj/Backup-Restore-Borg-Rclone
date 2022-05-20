## **Script de backup e restauração usando Borg Backup e rclone**

Este Script realiza o Backup e a Restauração das configurações do `Nexcloud` instalados por meio de pacotes `snap`, assim como a pasta `/Nextcloud/data` usando `Borg Backup` combinado com montagens `rclone` através de um serviço `systemctl`.

**Realizando Backup**

 1. Certifique-se de que os pacotes `rclone` e  `borg `estejam instalados. 
 2. Crie e criptografe seu arquivo `rclone.conf` `sudo gpg --batch --no-tty --homedir /path/to/.gnupg --passphrase-file '/path/to/senha.txt' -c /path/to/rclone.conf.`
 3. Faça uma copia do arquivo `example.conf` e o renomeie.
 4. Se preferir adicione as pastas para fazer backup no arquivo `patterns.lst`. Por Padrão o arquivo já esta pré-configurado para fazer backup das pastas `/var/snap/nextcloud/backups` `/var/snap/nextcloud/common/nextcloud/data` `/var/snap/nextcloud/current/certs` e excluir do backup a pasta `./files_trashbin`.
 5. Defina as variáveis em seu arquivo `.conf`, para que corresponda as suas necessidades.
 6. Se Preferir mova os arquivos `backup.sh`, `patterns.lst`, `restore.sh` e o arquivo recem editado `.conf` para uma pasta de sua preferência.
 7. Torne os scripts executáveis `sudo chmod a+x`.
 8. Altere as variáveis `AssertPathIsDirectory --config --cache-info-age=60m e ExecStop=/bin/fusermount -u` no arquivo `Backup.service`.
 9. Mova o `Backup.service` para a pasta `/etc/systemd/system`.
 10. Execute o script `backup.sh`ou agende o mesmo no Cron `00 00* * * sudo /path/to/backup.sh` 


**Restauração**

1. Execute o comando `sudo borg list /path-to-your-repo.`
2. Anote ou copie a data do backup que deseja restaurar 
3. Informe a data na variável `DATARESTORE` em seu arquivo `.conf`
4. Altere o caminho na variável `NEXTCLOUD_CONFIG` em seu arquivo `.conf` para que corresponda ao caminho exato onde o Nextcloud despejou as configurações exportadas. Geralmente `/var/snap/nextcloud/common/backups/20220430-200029`.
5. Execute o script `restore.sh` ou agende o mesmo no cron `00 00* * * sudo /path/to/restore.sh`
6. Caso queira restaurar a pasta `./Nextcloud/data` em um HD Externo, altere as variáveis `DEVICE` e `MOUNTDIR` em seu arquivo `.conf`, e descomente o intervalo de linhas de 23 a 42 em seu script `restore.sh` 

### Algumas Observações Importantes 

Observe que suponho que você fará a restauração no mesmo dispositivo e queira efetuar a restauração completa de sua pasta principal sem a necessidade de inserir informações no terminal.

Estes scripts realiza o backup e restauração das configurações do Nextcloud através dos comandos `nextcloud.export` e `nextcloud.import`. Caso prefira fazer o backup manual do `Nextcloud` adicione em seu arquivo `patterns.lst` os caminhos `/var/snap/nextcloud` `/snap/nextcloud` e comente as linhas referente a exportação importação nos scripts `backup.sh` `restore.sh`.

A Criptografia do arquivo `rclone.conf` é opcional, caso não tenha interesse comente as linhas referente a gpg tanto no arquivo `backup.sh e restore.sh.`

Em testes realizados o tempo de backup e restauração foram parecidos ou ate mesmo mais rápidos do que backups e restaurações realizados com os programas `duplicity ou deja-dup.`

