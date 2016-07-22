#!/bin/bash

# https://www.nagios.org/downloads/nagios-core/thanks/?t=1468953420
# https://library.nagios.com/library/products/nagioscore/documentation/567-installing-nagios-core-from-source
# http://unix.rocks/2014/nginx-and-nagios-a-howto
# http://idevit.nl/node/93
# https://www.nginx.com/resources/wiki/start/topics/examples/fcgiwrap/
# https://library.nagios.com/library/products/nagioscore/documentation/859-nagios-core-installing-on-centos-7

_APP_NAME="Nagios"
_NAGIOS_LAST_VERSION="4.1.1"
_PLUGINS_LAST_VERSION="2.1.1"
_OPTIONS_LIST="install_nagios_core 'Install $_APP_NAME' \
               configure_nginx 'Configure host on NGINX'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="http://prodigasistemas.github.io"

  ping -c 1 $(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g' | cut -d: -f1) > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

install_nagios_core () {
  _NAGIOS_VERSION=$(input_field "nagios.version" "$_APP_NAME version" "$_NAGIOS_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_NAGIOS_VERSION" ] && message "Alert" "The $_APP_NAME version can not be blank!"

  _PLUGINS_VERSION=$(input_field "nagios.plugins.version" "plugins version" "$_PLUGINS_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_PLUGINS_VERSION" ] && message "Alert" "The plugins version can not be blank!"

  _USER_NAME=$(input_field "nagios.user.name" "Enter the user name")
  [ $? -eq 1 ] && main
  [ -z "$_USER_NAME" ] && message "Alert" "The user name can not be blank!"

  _USER_PASSWORD=$(input_field "nagios.user.password" "Enter the user password")
  [ $? -eq 1 ] && main
  [ -z "$_USER_PASSWORD" ] && message "Alert" "The user password can not be blank!"

  confirm "Do you confirm the installation of $_APP_NAME?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      $_PACKAGE_COMMAND update

      _OS_VERSION=$(echo $_OS_NUMBER | cut -d. -f1)

      if [ "$_OS_VERSION" -le 14 ]; then
        _PHP_VERSION=$(php_version | cut -d. -f1)
        _PHP_INSTALL="php$_PHP_VERSION"
        _PHP_FPM_FOLDER="$_PHP_INSTALL/fpm/pool.d"
        _PACKAGES="libgd2-xpm-dev"
      else
        _PHP_VERSION="$(php_version | cut -d. -f1).$(php_version | cut -d. -f2)"
        _PHP_INSTALL="php"
        _PHP_FPM_FOLDER="php/$_PHP_VERSION/fpm/pool.d"
        _PACKAGES="libgd-dev"
      fi

      _LISTEN_OWNER="^listen.owner = www-data"
      _LISTEN_GROUP="^listen.group = www-data"

      $_PACKAGE_COMMAND install -y wget unzip build-essential sendmail apache2-utils spawn-fcgi fcgiwrap $_PHP_INSTALL-gd $_PHP_INSTALL-fpm $_PACKAGES
      ;;
    rpm)
      disable_selinux

      $_PACKAGE_COMMAND install -y httpd php php-cli gcc glibc glibc-common gd gd-devel net-snmp openssl-devel wget unzip

      admin_service httpd register
      admin_service httpd start
      ;;
  esac

  useradd nagios
  groupadd nagcmd
  usermod -a -G nagcmd nagios
  [ "$_OS_TYPE" = "rpm" ] && usermod -a -G nagcmd apache

  _NAGIOS_FILE="nagios-$_NAGIOS_VERSION.tar.gz"

  wget https://assets.nagios.com/downloads/nagioscore/releases/$_NAGIOS_FILE

  [ $? -ne 0 ] && message "Error" "Download of $_NAGIOS_FILE not realized!"

  tar -xzf $_NAGIOS_FILE

  rm $_NAGIOS_FILE

  cd ${_NAGIOS_FILE%.tar.gz}

  ./configure --prefix /opt/nagios \
              --sysconfdir=/etc/nagios \
              --with-nagios-group=nagios \
              --with-command-group=nagcmd \
              --with-mail=/usr/bin/sendmail

  make all
  make install
  make install-init
  make install-commandmode
  make install-config
  [ "$_OS_TYPE" = "rpm" ] && make install-webconf

  cp -R contrib/eventhandlers/ /opt/nagios/libexec/

  mkdir /var/log/nagios
  touch /var/log/nagios/nagios.log
  chown nagios:nagios -R /var/log/nagios

  change_file "replace" "/etc/nagios/nagios.cfg" "^log_file=/opt/nagios/var/nagios.log" "log_file=/var/log/nagios/nagios.log"

  if [ "$_OS_TYPE" = "deb" ]; then
    change_file "replace" "/etc/$_PHP_FPM_FOLDER/www.conf" "$_LISTEN_OWNER" "listen.owner = nginx"
    change_file "replace" "/etc/$_PHP_FPM_FOLDER/www.conf" "$_LISTEN_GROUP" "listen.group = www-data"
    rm /etc/$_PHP_FPM_FOLDER/www.conf-backup*

    change_file "replace" "/etc/init.d/fcgiwrap" "^FCGI_SOCKET_OWNER=\"www-data\"" "FCGI_SOCKET_OWNER=\"nginx\""
    rm /etc/init.d/fcgiwrap-backup*

    cp /usr/share/doc/fcgiwrap/examples/nginx.conf /etc/nginx/fcgiwrap.conf
  fi

  /opt/nagios/bin/nagios -v /etc/nagios/nagios.cfg

  admin_service nagios register
  admin_service nagios start

  htpasswd -cb /etc/nagios/htpasswd.users $_USER_NAME $_USER_PASSWORD

  cd ..

  rm -rf ${_NAGIOS_FILE%.tar.gz}

  _PLUGINS_FILE="nagios-plugins-$_PLUGINS_VERSION.tar.gz"

  wget http://nagios-plugins.org/download/$_PLUGINS_FILE

  [ $? -ne 0 ] && message "Error" "Download of $_PLUGINS_FILE not realized!"

  tar -xzf $_PLUGINS_FILE

  rm $_PLUGINS_FILE

  cd ${_PLUGINS_FILE%.tar.gz}

  ./configure --prefix /opt/nagios --with-nagios-user=nagios --with-nagios-group=nagios

  make
  make install

  cd ..

  rm -rf ${_PLUGINS_FILE%.tar.gz}

  chown nagios:nagios -R /opt/nagios

  if [ "$_OS_TYPE" = "deb" ]; then
    admin_service "php$_PHP_VERSION-fpm" restart
    admin_service fcgiwrap restart
  fi

  admin_service nagios restart

  [ $? -eq 0 ] && message "Notice" "$_APP_NAME successfully installed!"
}

configure_nginx () {
  [ "$_OS_TYPE" != "deb" ] && message "Alert" "NGINX is not configured because OS type is different that debian like!"

  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "nagios.nginx.domain" "Enter the domain of $_APP_NAME" "nagios.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    case "$_OS_TYPE" in
      deb)
        if [ "$_OS_VERSION" -le 14 ]; then
          _PHP_VERSION=$(php_version | cut -d. -f1)
          _PHP_SOCK_FILE="php$_PHP_VERSION-fpm.sock"
        else
          _PHP_VERSION="$(php_version | cut -d. -f1).$(php_version | cut -d. -f2)"
          _PHP_SOCK_FILE="php/php$_PHP_VERSION-fpm.sock"
        fi
        ;;
    esac

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/nagios.conf" > nagios.conf

    change_file replace nagios.conf DOMAIN $_DOMAIN
    change_file replace nagios.conf PHP_SOCK_FILE $_PHP_SOCK_FILE

    mv nagios.conf /etc/nginx/conf.d/
    rm nagios.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed! $_APP_NAME host not configured!"
  fi
}

main () {
  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app nagios)" ] && install_nagios_core
    [ -n "$(search_app nagios.nginx)" ] && configure_nginx
  fi
}

setup
main
