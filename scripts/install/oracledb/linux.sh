#!/bin/bash

# http://www.oracle.com/technetwork/database/database-technologies/express-edition/overview/index.html
# https://hub.docker.com/r/wnameless/oracle-xe-11g/
# http://www.orafaq.com/wiki/NLS_LANG
# http://stackoverflow.com/questions/19335444/how-to-assign-a-port-mapping-to-an-existing-docker-container

_OPTIONS_LIST="install_oracleb 'Install Oracle Database 11g Express Edition with Docker' \
               import_ggas_database 'Import GGAS Database'"

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -is | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
  fi

  _TITLE="--backtitle \"Oracle Database installation (https://hub.docker.com/r/wnameless/oracle-xe-11g) - OS: $_OS_DESCRIPTION\""
}

tool_check() {
  echo "Checking for $1..."
  if command -v $1 > /dev/null; then
    echo "Detected $1..."
  else
    echo "Installing $1..."
    $_PACKAGE_COMMAND install -y $1
  fi
}

menu () {
  echo $(eval dialog $_TITLE --stdout --menu \"$1\" 0 0 0 $2)
}

input () {
  echo $(eval dialog $_TITLE --stdout --inputbox \"$1\" 0 0 \"$2\")
}

message () {
  eval dialog --title \"$1\" --msgbox \"$2\" 0 0
  main
}

run_as_root () {
  su -c "$1"
}

install_oracleb () {
  _SSH_PORT=$(input "Inform the ssh port (22) to be exported" "2222")
  [ $? -eq 1 ] && main
  [ -z "$_SSH_PORT" ] && message "Alert" "The ssh port can not be blank!"

  _CONECTION_PORT=$(input "Inform the connection port (1521) to be exported" "1521")
  [ $? -eq 1 ] && main
  [ -z "$_CONECTION_PORT" ] && message "Alert" "The connection port can not be blank!"

  _HTTP_PORT=$(input "Inform the http port (8080) to be exported" "5050")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  dialog --yesno "Confirm the installation of Oracle Database in $_OS_DESCRIPTION?" 0 0
  [ $? -eq 1 ] && main

  docker run --name oracle-xe-11g -d -p $_SSH_PORT:22 -p $_CONECTION_PORT:1521 -p $_HTTP_PORT:8080 --restart="always" wnameless/oracle-xe-11g

  message "Notice" "Oracle Database successfully installed!"
}

import_ggas_database () {
  dialog --yesno "Confirms the import of GGAS database?" 0 0
  [ $? -eq 1 ] && main

  git clone http://ggas.com.br/root/ggas.git
}

main () {
  tool_check dialog
  tool_check git

  if [ $_OS_ARCH = "32" ]; then
    dialog --title "Alert" --msgbox "Oracle Database requires a 64-bit installation regardless of your distribution version!" 0 0
    clear && exit 0
  fi

  if command -v docker > /dev/null; then
    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    dialog --title "Alert" --msgbox "Docker is not installed" 0 0
    clear && exit 0
  fi
}

os_check
main
