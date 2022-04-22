### **Script de backup e restauração usando Borg Backup e rclone**

Este é um script básico para realizar backups automáticos usando Borg Backup e rclone. Ele usa um serviço systemd para montar um remoto rclone em uma pasta especifica como `/mnt/`.

**Realizando Backup**

 1. Certifique-se de que os pacotes `rclone` e  `borg `estejam instalados. 
 2. Crie e criptografe seu arquivo `rclone.conf` `sudo gpg --batch --no-tty --homedir /path/to/.gnupg --passphrase-file '/path/to/senha.txt' -c /path/to/rclone.conf.`
 3. Defina o local do seu repositório na parte superior do script `export BORG_REPO=/path/to/folder/Repo.`
 4. Defina as variáveis ​​para se adequar ao seu ambiente.
 5. Altere as variáveis `AssertPathIsDirectory --config --cache-info-age=60m e ExecStop=/bin/fusermount -u` no arquivo `Backup.service`
 6. Copie os 2 scripts para uma pasta de sua preferência. ou seja, scripts/backup.
 7. Mova o`Backup.service`para as pastas apropriadas para que o systemd possa executá-los. Provavelmente `/etc/systemd/system`, mas isso pode variar dependendo da sua distribuição.
 8. Vá para a pasta onde colocou os scripts e os torne executáveis com o comando `sudo chmod a+x`.
 9. Execute o backup: `sudo /path/to/backup.sh`.
10. Agende o backup no Cron: `00 00* * * sudo /path/to/backup.sh`

**Restauração**

1. Liste os arquivos Borg para recuperar o nome do arquivo que você deseja restaurar: `sudo borg list /path-to-your-repo.` 
2. Copie a ultima data onde foi realizado o backup e execute o comando: `sudo sed -i 's/data-Antiga/Nova-data/'`, ou se preferir edite o script `/restore.sh` com editor de sua preferencia e altere a data na variávei `DATARESTORE`
3. Agende a restauração no Cron: `00 01* * 6 sudo /path/to/restore.sh`

Observe que suponho que você fará a restauração no mesmo dispositivo e queira efetuar a restauração completa de sua pasta principal sem a necessidade de inserir dados no terminal.

A Criptografia do arquivo  `rclone.conf`é opcional, se não for querer criptografar e só comentar as linhas referente a gpg tanto no arquivo `backup.sh e restore.sh.`

Em testes realizados o tempo de backup e restauração foram parecidos ou ate mesmo mais rápidos do que backups e restaurações realizados com os programas `duplicity ou deja-dup.`
