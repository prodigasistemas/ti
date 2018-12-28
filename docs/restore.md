# Restore

O script realiza a tarefa de restauração de pastas e banco de dados executadas pelo script de backup, acessando cada servidor registrado via conexão ssh.

## Observações

* Os bancos de dados são restaurados somente se não existir usuário e banco com o mesmo nome no servidor.
* As pastas são sincronizadas com a pasta compactada.

## Local de leitura

    /opt/tools/backup
