#!/bin/bash

# http://www.orafaq.com/wiki/NLS_LANG

_APP_NAME="GGAS"
_OPTIONS_LIST="install_ggas 'Install GGAS' \
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

install_ggas () {
  message "Alert" "Coming soon"
}

import_ggas_database () {
  _CURRENT_DIR=$(pwd)

  if [ -e "$_ORACLE_CONFIG" ]; then
    _SSH_PORT=$(search_value ssh.port $_ORACLE_CONFIG)
  else
    _SSH_PORT=2222
  fi

  ssh -p $_SSH_PORT root@localhost

  [ $? -ne 0 ] && message "Error" "ssh: connect to host localhost port $_SSH_PORT: Connection refused"

  confirm "Confirm import GGAS database?"
  [ $? -eq 1 ] && main

  tool_check git

  cd /tmp

  delete_file "/tmp/ggas"

  echo
  echo "=================================================="
  echo "Cloning repo from http://ggas.com.br/root/ggas.git"
  echo "=================================================="
  git clone http://ggas.com.br/root/ggas.git

  [ $? -ne 0 ] && message "Error" "Download of GGAS not realized!"

  _SEARCH_STRING="CREATE OR REPLACE FUNCTION \"GGAS_ADMIN\".\"SQUIRREL_GET_ERROR_OFFSET\""
  change_file "replace" "ggas/sql/GGAS_SCRIPT_INICIAL_ORACLE_02_ESTRUTURA_CONSTRAINTS_CARGA_INICIAL.sql" "$_SEARCH_STRING" "-- $_SEARCH_STRING"

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
  scp -P $_SSH_PORT -r ggas/sql root@localhost:/tmp

  echo
  echo "======================================="
  echo "Import SQL files to container Oracle DB"
  echo "======================================="
  ssh -p $_SSH_PORT root@localhost "/tmp/sql/import_db.sh"

  delete_file "/tmp/ggas"

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "Import GGAS database was successful!"
}

main () {
  tool_check dialog

  _TI_FOLDER="/opt/tools-installer"
  _ORACLE_CONFIG="$_TI_FOLDER/oracle.conf"

  if [ "$(provisioning)" = "manual" ]; then
    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ "$(search_value ggas.import.database)" = "yes" ] && import_ggas_database
  fi
}

setup
main
