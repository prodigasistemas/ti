#!/bin/bash

# http://www.oracle.com/technetwork/database/database-technologies/express-edition/overview/index.html
# https://hub.docker.com/r/wnameless/oracle-xe-11g/
# http://www.orafaq.com/wiki/NLS_LANG
# http://stackoverflow.com/questions/19335444/how-to-assign-a-port-mapping-to-an-existing-docker-container

_APP_NAME="Oracle Database XE"
_OPTIONS_LIST="install_oracleb 'Install Oracle Database 11g Express Edition with Docker' \
               import_ggas_database 'Import GGAS Database'"

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

install_oracleb () {
  _SSH_PORT=$(input_field "oracledb.port.ssh" "Inform the ssh port (22) to be exported" "2222")
  [ $? -eq 1 ] && main
  [ -z "$_SSH_PORT" ] && message "Alert" "The ssh port can not be blank!"

  _CONECTION_PORT=$(input_field "oracledb.port.connection" "Inform the connection port (1521) to be exported" "1521")
  [ $? -eq 1 ] && main
  [ -z "$_CONECTION_PORT" ] && message "Alert" "The connection port can not be blank!"

  _HTTP_PORT=$(input_field "oracledb.port.http" "Inform the http port (8080) to be exported" "5050")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  confirm "Confirm the installation of Oracle Database in $_OS_DESCRIPTION?"
  [ $? -eq 1 ] && main

  docker run --name oracle-xe-11g -d -p $_SSH_PORT:22 -p $_CONECTION_PORT:1521 -p $_HTTP_PORT:8080 --restart="always" wnameless/oracle-xe-11g

  [ $? -eq 0 ] && message "Notice" "Oracle Database successfully installed!"
}

import_ggas_database () {
  confirm "Confirms the import of GGAS database?"
  [ $? -eq 1 ] && main

  delete_file "ggas"

  echo
  echo "=================================================="
  echo "Cloning repo from http://ggas.com.br/root/ggas.git"
  echo "=================================================="
  git clone http://ggas.com.br/root/ggas.git

  _SEARCH_STRING="CREATE OR REPLACE FUNCTION \"GGAS_ADMIN\".\"SQUIRREL_GET_ERROR_OFFSET\""
  change_file replace ggas/sql/GGAS_SCRIPT_INICIAL_ORACLE_02_ESTRUTURA_CONSTRAINTS_CARGA_INICIAL.sql "$_SEARCH_STRING" "-- $_SEARCH_STRING"

  for i in ggas/sql/*.sql ; do echo " " >> $i ; done
  for i in ggas/sql/*.sql ; do echo "exit;" >> $i ; done

  mkdir ggas/sql/01 ggas/sql/02

  mv ggas/sql/GGAS_SCRIPT_INICIAL_ORACLE_0*.sql ggas/sql/01/
  mv ggas/sql/*.sql ggas/sql/02/

  _IMPORT_SCRIPT="ggas/sql/import_db.sh"
  echo '#!/bin/bash' > $_IMPORT_SCRIPT
  echo 'export NLS_LANG=AMERICAN_AMERICA.AL32UTF8' >> $_IMPORT_SCRIPT
  echo 'export PATH=$PATH:/u01/app/oracle/product/11.2.0/xe/bin' >> $_IMPORT_SCRIPT
  echo 'export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe' >> $_IMPORT_SCRIPT
  echo 'export ORACLE_SID=XE' >> $_IMPORT_SCRIPT
  echo 'for i in /tmp/sql/01/*.sql ; do echo "> Importing file $i ..." ; sqlplus system/oracle @$i ; done' >> $_IMPORT_SCRIPT
  echo 'for i in /tmp/sql/02/*.sql ; do echo "> Importing file $i ..." ; sqlplus GGAS_ADMIN/GGAS_ADMIN @$i ; done' >> $_IMPORT_SCRIPT
  chmod +x $_IMPORT_SCRIPT

  echo
  echo "===================================================="
  echo "you must run the commands in the container Oracle DB"
  echo "The root password is 'admin'"
  echo "===================================================="

  echo
  echo "====================================="
  echo "Copy SQL files to container Oracle DB"
  echo "====================================="
  #TODO: get port ssh (22) exported from container
  scp -P 2222 -r ggas/sql root@localhost:/tmp

  echo
  echo "======================================="
  echo "Import SQL files to container Oracle DB"
  echo "======================================="
  ssh -p 2222 root@localhost "/tmp/sql/import_db.sh"

  [ $? -eq 0 ] && message "Notice" "Import GGAS database was successful!"
}

main () {
  tool_check dialog
  tool_check git

  if [ "$_OS_ARCH" = "32" ]; then
    message "Alert" "Oracle Database requires a 64-bit installation regardless of your distribution version!" "clear && exit 1"
  else
    if [ "$(provisioning)" = "manual" ]; then
      if command -v docker > /dev/null; then
        _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

        if [ -z "$_OPTION" ]; then
          clear && exit 0
        else
          $_OPTION
        fi
      else
        message "Alert" "Docker is not installed" "clear && exit 1"
      fi
    else
      [ ! -z "$(search_app oracledb)" ] && install_oracleb
      [ "$(search_value oracledb.import_ggas_database)" = "yes" ] && import_ggas_database
    fi
  fi
}

setup
main
