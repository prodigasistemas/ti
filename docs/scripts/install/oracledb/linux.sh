#!/bin/bash

# http://www.oracle.com/technetwork/database/database-technologies/express-edition/overview/index.html
# https://hub.docker.com/r/wnameless/oracle-xe-11g/
# http://stackoverflow.com/questions/19335444/how-to-assign-a-port-mapping-to-an-existing-docker-container

export _APP_NAME="Oracle Database XE"
_OPTIONS_LIST="install_oracleb 'Install Oracle Database 11g Express Edition with Docker'"

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

install_oracleb () {
  [ "$_OS_ARCH" = "32" ] && message "Alert" "Oracle Database requires a 64-bit installation regardless of your distribution version!"

  _DOCKER_INSTALLED=$(command -v docker)
  [ -z "$_DOCKER_INSTALLED" ] && message "Alert" "Docker is not installed"

  _SSH_PORT=$(input_field "oracledb.port.ssh" "Inform the ssh port (22) to be exported" "2222")
  [ $? -eq 1 ] && main
  [ -z "$_SSH_PORT" ] && message "Alert" "The ssh port can not be blank!"

  _CONECTION_PORT=$(input_field "oracledb.port.connection" "Inform the connection port (1521) to be exported" "1521")
  [ $? -eq 1 ] && main
  [ -z "$_CONECTION_PORT" ] && message "Alert" "The connection port can not be blank!"

  _HTTP_PORT=$(input_field "oracledb.port.http" "Inform the http port (8080) to be exported" "5050")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  confirm "Source: hub.docker.com/r/wnameless/oracle-xe-11g\n\nConfirm the installation of Oracle Database in $_OS_DESCRIPTION?"
  [ $? -eq 1 ] && main

  [ ! -e "$_TI_FOLDER" ] && mkdir -p "$_TI_FOLDER"

  echo "ssh.port = $_SSH_PORT" > "$_ORACLE_CONFIG"
  echo "connection.port = $_CONECTION_PORT" >> "$_ORACLE_CONFIG"
  echo "http.port = $_HTTP_PORT" >> "$_ORACLE_CONFIG"

  docker run --name oracle-xe-11g -d -p "$_SSH_PORT:22" -p "$_CONECTION_PORT:1521" -p "$_HTTP_PORT:8080" --restart="always" wnameless/oracle-xe-11g

  [ $? -eq 0 ] && message "Notice" "Oracle Database successfully installed! Source: hub.docker.com/r/wnameless/oracle-xe-11g"
}

main () {
  _TI_FOLDER="/opt/tools-installer"
  _ORACLE_CONFIG="$_TI_FOLDER/oracle.conf"

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app oracledb)" ] && install_oracleb
  fi
}

setup
main
