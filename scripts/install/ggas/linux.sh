#!/bin/bash

# http://www.orafaq.com/wiki/NLS_LANG

_APP_NAME="GGAS"
_DEFAULT_PATH="/opt"
_GRADLE_VERSION="2.2.1"
_OPTIONS_LIST="install_ggas 'Install GGAS' \
               import_ggas_database 'Import GGAS Database' \
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

install_ggas () {
  _CURRENT_DIR=$(pwd)

  java_check 7

  [ ! -e "$_DEFAULT_PATH/wildfly" ] && message "Error" "Wildfly is not installed!"

  confirm "Confirm the installation of $_APP_NAME?"
  [ $? -eq 1 ] && main

  tool_check git
  tool_check wget
  tool_check unzip

  cd $_DEFAULT_PATH

  delete_file "$_DEFAULT_PATH/ggas"

  print_colorful yellow bold "> Cloning repo from http://ggas.com.br/root/ggas.git..."

  git clone http://ggas.com.br/root/ggas.git

  [ $? -ne 0 ] && message "Error" "Download of $_APP_NAME not realized!"

  print_colorful yellow bold "> Installing Gradle $_GRADLE_VERSION..."

  cd $_DEFAULT_PATH

  wget https://services.gradle.org/distributions/gradle-$_GRADLE_VERSION-bin.zip

  [ $? -ne 0 ] && message "Error" "Download of Gradle $_GRADLE_VERSION not realized!"

  unzip -oq gradle-$_GRADLE_VERSION-bin.zip

  rm gradle-$_GRADLE_VERSION-bin.zip

  ln -sf gradle-$_GRADLE_VERSION $_DEFAULT_PATH/gradle

  print_colorful yellow bold "> Building $_APP_NAME..."

  cd $_DEFAULT_PATH/ggas

  JAVA_HOME=$(get_java_home 7) $_DEFAULT_PATH/gradle/bin/gradle build

  print_colorful yellow bold "> Deploying $_APP_NAME..."

  /etc/init.d/wildfly stop

  cp $_DEFAULT_PATH/ggas/workspace/build/libs/workspace*.war $_DEFAULT_PATH/wildfly/standalone/deployments/ggas.war

  /etc/init.d/wildfly start

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "$_APP_NAME successfully installed!"
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

  confirm "Confirm import $_APP_NAME database?"
  [ $? -eq 1 ] && main

  if [ ! -e "$_DEFAULT_PATH/ggas" ]; then
    cd $_DEFAULT_PATH
    tool_check git

    print_colorful yellow bold "> Cloning repo from http://ggas.com.br/root/ggas.git..."

    git clone http://ggas.com.br/root/ggas.git
    [ $? -ne 0 ] && message "Error" "Download of GGAS not realized!"
  fi

  delete_file "/tmp/ggas"
  cp -r $_DEFAULT_PATH/ggas/sql /tmp/ggas/
  cd /tmp/ggas

  _SEARCH_STRING="CREATE OR REPLACE FUNCTION \"GGAS_ADMIN\".\"SQUIRREL_GET_ERROR_OFFSET\""
  change_file "replace" "ggas/sql/GGAS_SCRIPT_INICIAL_ORACLE_02_ESTRUTURA_CONSTRAINTS_CARGA_INICIAL.sql" "$_SEARCH_STRING" "-- $_SEARCH_STRING"

  for i in sql/*.sql ; do echo " " >> $i ; done
  for i in sql/*.sql ; do echo "exit;" >> $i ; done

  mkdir sql/01 ggas/sql/02

  mv sql/GGAS_SCRIPT_INICIAL_ORACLE_0*.sql sql/01/
  mv sql/*.sql sql/02/

  _IMPORT_SCRIPT="ggas/sql/import_db.sh"
  echo '#!/bin/bash' > $_IMPORT_SCRIPT
  echo 'export NLS_LANG=AMERICAN_AMERICA.AL32UTF8' >> $_IMPORT_SCRIPT
  echo 'export PATH=$PATH:/u01/app/oracle/product/11.2.0/xe/bin' >> $_IMPORT_SCRIPT
  echo 'export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe' >> $_IMPORT_SCRIPT
  echo 'export ORACLE_SID=XE' >> $_IMPORT_SCRIPT
  echo 'for i in /tmp/sql/01/*.sql ; do echo "> Importing file $i ..." ; sqlplus system/oracle @$i ; done' >> $_IMPORT_SCRIPT
  echo 'for i in /tmp/sql/02/*.sql ; do echo "> Importing file $i ..." ; sqlplus GGAS_ADMIN/GGAS_ADMIN @$i ; done' >> $_IMPORT_SCRIPT
  chmod +x $_IMPORT_SCRIPT

  print_colorful yellow bold "> You must run the commands in the container Oracle DB. The root password is 'admin'"

  print_colorful yellow bold "> Copy SQL files to container Oracle DB"

  scp -P $_SSH_PORT -r sql root@localhost:/tmp

  print_colorful yellow bold "> Import SQL files to container Oracle DB"

  ssh -p $_SSH_PORT root@localhost "/tmp/sql/import_db.sh"

  delete_file "/tmp/ggas"

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "Import $_APP_NAME database was successful!"
}

configure_nginx () {
  _PORT=$(cat /opt/wildfly/standalone/configuration/standalone.xml | grep "jboss.http.port" | cut -d: -f2 | cut -d} -f1)
  _DEFAULT_HOST="localhost:$_PORT"

  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "ggas.nginx.domain" "Enter the domain of GGAS" "ggas.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input_field "ggas.nginx.host" "Enter the host of GGAS server" "$_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > ggas.conf

    change_file replace ggas.conf APP ggas
    change_file replace ggas.conf DOMAIN $_DOMAIN
    change_file replace ggas.conf HOST $_HOST

    mv ggas.conf /etc/nginx/conf.d/
    rm ggas.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed! GGAS host not configured!"
  fi
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
    [ -n "$(search_app ggas)" ] && install_ggas
    [ "$(search_value ggas.import.database)" = "yes" ] && import_ggas_database
    [ -n "$(search_app ggas.nginx)" ] && configure_nginx
  fi
}

setup
main
