### **Script de backup usando Borg Backup e rclone**

Este é um script básico para realizar backups automáticos usando Borg Backup e rclone. Ele usa um serviço systemd para montar um remoto rclone em uma pasta especifica como `/mnt/`.

**Configuração**

* Certifique-se de que os pacotes `rclone`e estejam instalados e operacionais.`borg`
* *Opcional* : Criptografe o arquivo `rclone.conf` `sudo gpg --batch --no-tty --homedir /root/.gnupg --passphrase-file '/root/.config/backup/gpg-pass.txt' -c /home/usr/.config/rclone/rclone.conf,`o mesmo sera descriptografado ao executar o script e ao finalizar o backup a unidade sera desmontada e o arquivo descriptografado sera removido.
* Mova o`borg.service`para as pastas apropriadas para que o systemd possa executá-los. Provavelmente `/etc/systemd/system`, mas isso pode variar dependendo da sua distribuição.

**Referência de configuração**

Aqui está uma breve descrição das várias opções para definir.

* `--homedir`: Local onde as chaves e senhas GPG são armazenadas (root).
* `--passphrase-file`: Local onde está o armazenado a senha para descriptografar o arquivo`rclone.conf`
* `-c: `A localização do arquivo `rclone.conf`
* `BORG_PASSPHRASE`: A senha para seu repositório borg
* `BORG_REPO`: A localização do repositório local. Este repositório é o que será sincronizado com o controle remoto rclone. Os arquivos de repositório, portanto, existirão em sua máquina local e no remoto.
* `LOGFILE_PATH`: Onde serão armazenados os logs gerados pelo script. Você provavelmente deve localizar esse arquivo no mesmo local que o script e o arquivo de ambiente.

`borg.service`

* `AssertPathIsDirectory`: Local de montagem .
* `--config`: Local onde encontra-se o arquivo rclone.conf.
* `--cache-info-age=60m`: informe o nome do remoto, exemplo Gdrive:/ e o local de montagem /mnt
* `ExecStop=/bin/fusermount -u` forneça o caminho onde foi montado o remoto.