# Pródiga Sistemas - Tools Installer

Central de instalação de ferramentas Open Source utilizadas por nós.

Desenvolvida em [Shell Script](http://aurelio.net/shell/) e [Dialog](http://aurelio.net/shell/dialog/).

## Ambiente de desenvolvimento

### Baixe o projeto e o copie para um servidor web. Execute:

    curl -sS <SERVIDOR>[:PORTA]/scripts/menu/linux.sh | sudo _CENTRAL_URL_TOOLS=<SERVIDOR>[:PORTA] bash

## Provisionamento automático

As receitas de instalação estão disponíveis em scripts/recipes. Basta você criar um arquivo recipe.ti e executar o mesmo comando acima para as ferramentas serem instaladas e configuradas automaticamente.

## Licença

Tools Installer é liberado sob a [MIT License](http://www.opensource.org/licenses/MIT).
