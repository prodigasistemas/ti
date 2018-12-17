# Tools Installer

Instale e configure, rapidamente, ferramentas em plataformas Linux

Desenvolvido em [Shell Script](http://aurelio.net/shell/) e [Dialog](http://aurelio.net/shell/dialog/).

## Ambiente de desenvolvimento

### Instale o servidor web lighttpd
http://redmine.lighttpd.net/projects/lighttpd/wiki/TutorialConfiguration

    sudo apt-get install lighttpd

### Copie e edite o caminho da variável "server.document-root" do arquivo de configuração

    cp lighttpd.conf.example lighttpd.conf

### Execute o servidor local

    ./localserver.sh

### Baixe o projeto e o copie para um servidor web. Execute:

    SERVIDOR=<IP-DO-SERVIDOR>:5000

    curl -sS $SERVIDOR/scripts/menu/linux.sh | sudo _CENTRAL_URL_TOOLS=$SERVIDOR bash

## Provisionamento automático

As receitas de instalação estão disponíveis em scripts/recipes. Basta você criar um arquivo recipe.ti e executar o mesmo comando acima para as ferramentas serem instaladas e configuradas automaticamente.

## Licença

Tools Installer é liberado sob a [MIT License](http://www.opensource.org/licenses/MIT).
