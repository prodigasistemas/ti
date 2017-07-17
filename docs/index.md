# Tools Installer

## Instale e configure, rapidamente, ferramentas nas plataformas Linux
![Linux support](https://prodigasistemas.github.io/images/linux_support.png)

## Ferramentas
* Servidor de automação
  * [Jenkins](https://jenkins.io/)
* Servidor web
  * [Nginx](https://www.nginx.com/)
* Banco de dados
  * [MySQL](https://www.mysql.com/)
  * [PostgreSQL](https://www.postgresql.org/)

## É preciso ter instalado o pacote curl

### No Debian ou Ubuntu
    sudo apt-get -y install curl

### No CentOS
    sudo yum -y install curl

## Provisionamento manual

O comando abaixo inicia o menu principal para instalação das ferramentas

    curl -sS https://prodigasistemas.github.io/ti/scripts/menu/linux.sh | sudo bash

![manual installer](https://prodigasistemas.github.io/images/tools-installer-manual.png)

## Provisionamento automático

As receitas de instalação estão disponíveis [no link](https://github.com/prodigasistemas/prodigasistemas.github.io/tree/master/scripts/recipes). Basta você criar um arquivo recipe.ti e executar o mesmo comando acima para as ferramentas serem instaladas e configuradas automaticamente.

### Exemplo de instalação do Jenkins Automation Server

    curl -sS https://prodigasistemas.github.io/ti/scripts/recipes/jenkins/recipe.ti > recipe.ti

    curl -sS https://prodigasistemas.github.io/ti/scripts/menu/linux.sh | sudo bash

![automatic installer](https://prodigasistemas.github.io/images/tools-installer-automatic.png)

[Pródiga Sistemas](http://www.prodigasistemas.com.br) © 2016
