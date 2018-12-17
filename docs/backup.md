# backup.sh

O scritp realiza a tarefa de backup de pastas e banco de dados, em segundo plano, acessando cada servidor registrado via conexão ssh. Uma conexão com um servidor espelho por ser configurada via rsync ou aws bucket para replicar toda a pasta garantindo redundância dos backups realizados

## Local de instalação

    /opt/tools/backup

## Arquivos

* _backup.sh_ - gerencia o backup de pastas e banco de dados, executado via cron job às 23hs (podendo ser alterado)
* _backup.conf_ - definições dos servidores espelho via rsync ou bucket na Amazon Web Service. Você também pode configurar o número máximo de arquivos compactados que devem ser preservados para cada backup, o padrão é 7
* _hosts.list_ - lista de servidores com suas informações de conexão local ou via ssh

## Pastas

* _hosts_ - cada servidor registrado no arquivo _hosts.list_ deve possuir seu arquivo de configuração. Veja o arquivo _example.list_
* _logs_ - armazena os logs de cada servidor e das sincronizações realizadas com os servidores espelho
* _storage_ - armazena os arquivos de backup compactados, separados por pastas de cada servidor
