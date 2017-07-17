#!/bin/bash

# https://library.nagios.com/library/products/nagioscore/documentation/567-installing-nagios-core-from-source
# http://unix.rocks/2014/nginx-and-nagios-a-howto
# https://help.ubuntu.com/lts/serverguide/nagios.html
# http://tecadmin.net/install-nagios-monitoring-server-on-ubuntu/
# http://tecadmin.net/install-nrpe-on-ubuntu/
# http://tecadmin.net/install-nrpe-on-centos-rhel/
# http://tecadmin.net/monitor-remote-linux-host-using-nagios/
# https://assets.nagios.com/downloads/nagioscore/docs/nrpe/NRPE.pdf

export _APP_NAME="Nagios"
_OPTIONS_LIST="install_nagios_server 'Install $_APP_NAME server' \
               install_nagios_client 'Install $_APP_NAME client'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="https://prodigasistemas.github.io/ti"

  ping -c 1 "$(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g' | cut -d: -f1)" > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

centos_epel() {
  [ "$_OS_RELEASE" = "6" ] && _VERSION="6-8"
  [ "$_OS_RELEASE" = "7" ] && _VERSION="7-7"

  [ "$_OS_ARCH" = "32" ] && _ARCH="i386"
  [ "$_OS_ARCH" = "64" ] && _ARCH="x86_64"

  rpm -Uvh "http://mirror.globo.com/epel/$_OS_RELEASE/$_ARCH/epel-release-$_VERSION.noarch.rpm"

  [ $? -ne 0 ] && message "Error" "Download of epel-release-$_VERSION.noarch.rpm not realized!"
}

install_nagios_server () {
  confirm "Do you confirm the installation of $_APP_NAME server?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      _NAGIOS_SERVICE="nagios3"

      $_PACKAGE_COMMAND update

      $_PACKAGE_COMMAND install -y nagios3 nagios-plugins nagios-plugins-contrib nagios-plugins-extra nagios-nrpe-plugin
      ;;
    rpm)
      _NAGIOS_SERVICE="nagios"

      centos_epel

      $_PACKAGE_COMMAND --enablerepo=epel install -y nagios nagios-plugins nagios-plugins-all

      admin_service nagios register
      admin_service httpd register

      admin_service nagios start
      admin_service httpd start
      ;;
  esac

  _SERVERS_DIR="/etc/nagios3/servers"

  change_file "replace" "/etc/nagios3/nagios.cfg" "^#cfg_dir=$_SERVERS_DIR" "cfg_dir=$_SERVERS_DIR"

  mkdir $_SERVERS_DIR

  chown nagios:nagios -R $_SERVERS_DIR

  admin_service $_NAGIOS_SERVICE restart

  [ $? -eq 0 ] && message "Notice" "$_APP_NAME server successfully installed!"
}

install_nagios_client () {
  _SERVER_IP=$(input_field "[default]" "Enter the $_APP_NAME server IP")
  [ $? -eq 1 ] && main
  [ -z "$_SERVER_IP" ] && message "Alert" "The $_APP_NAME server IP can not be blank!"

  confirm "Do you confirm the installation of $_APP_NAME client?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      $_PACKAGE_COMMAND update

      $_PACKAGE_COMMAND install -y nagios-nrpe-server nagios-plugins nagios-plugins-contrib nagios-plugins-extra
      ;;
    rpm)
      centos_epel

      yum --enablerepo=epel install -y nrpe nagios-plugins nagios-plugins-all

      admin_service nrpe register
      admin_service nrpe start
      ;;
  esac

  change_file "replace" "/etc/nagios/nrpe.cfg" "^allowed_hosts=127.0.0.1" "allowed_hosts=127.0.0.1, $_SERVER_IP"

  admin_service nrpe restart

  [ $? -eq 0 ] && message "Notice" "$_APP_NAME client successfully installed!"
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
    [ -n "$(search_app nagios.server)" ] && install_nagios_server
  fi
}

setup
main
