#!/bin/bash

# http://www.mybatis.org/migrations/

_APP_NAME="GSAN"
_DEFAULT_PATH="/opt"
_MYBATIS_VERSION="3.2.0"
_MYBATIS_DESCRIPTION="MyBatis Migration"
_OPTIONS_LIST="install_mybatis_migration 'Install $_MYBATIS_DESCRIPTION' \
               install_gsan_migrations 'Install GSAN Migrations' \
               install_gsan 'Install GSAN'"

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

install_mybatis_migration () {
  _CURRENT_DIR=$(pwd)

  java_check 6

  _VERSION=$(input_field "gsan.mybatis.version" "Enter the $_MYBATIS_DESCRIPTION version" "$_MYBATIS_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && message "Alert" "The $_MYBATIS_DESCRIPTION version can not be blank!"

  _JAVA_HOME=$(input_field "gsan.java.home" "Enter the JAVA_HOME path" "$JAVA_HOME")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_HOME" ] && message "Alert" "The JAVA_HOME path can not be blank!"

  [ ! -e "$_JAVA_HOME" ] && message "Alert" "$_JAVA_HOME path not found!"

  confirm "Do you confirm the installation of $_MYBATIS_DESCRIPTION $_VERSION?"
  [ $? -eq 1 ] && main

  tool_check wget
  tool_check unzip

  _MYBATIS_FILE="mybatis-migrations-$_VERSION"

  cd $_DEFAULT_PATH

  wget https://github.com/mybatis/migrations/releases/download/$_MYBATIS_FILE/$_MYBATIS_FILE.zip

  [ $? -ne 0 ] && message "Error" "Download of $_MYBATIS_FILE.zip not realized!"

  unzip -o $_MYBATIS_FILE.zip

  ln -sf $_MYBATIS_FILE mybatis-migrations

  rm $_MYBATIS_FILE.zip

  _MAJOR_VERSION=$(echo $_VERSION | cut -d. -f1)
  _MYBATIS_JAR_FILE=$(ls $_DEFAULT_PATH/mybatis-migrations/lib/mybatis-$_MAJOR_VERSION*.jar | head -n 1)

  ln -sf $_DEFAULT_PATH/mybatis-migrations/lib/$_MYBATIS_JAR_FILE $_JAVA_HOME/jre/lib/ext/

  ln -sf $_DEFAULT_PATH/mybatis-migrations/lib/$_MYBATIS_FILE.jar $_JAVA_HOME/jre/lib/ext/

  ln -sf $_DEFAULT_PATH/mybatis-migrations/bin/migrate /usr/local/bin

  cd $_CURRENT_DIR

  migrate info

  [ $? -eq 0 ] && message "Notice" "$_MYBATIS_DESCRIPTION $_VERSION successfully installed!"
}

install_gsan_migrations () {
  _CURRENT_DIR=$(pwd)
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  _POSTGRESQL_INSTALLED=$(run_as_user $_USER_LOGGED "command -v psql")
  [ -z "$_POSTGRESQL_INSTALLED" ] && message "Error" "PostgreSQL Client or Server is not installed!"

  _MYBATIS_INSTALLED=$(run_as_user $_USER_LOGGED "command -v migrate")
  [ -z "$_MYBATIS_INSTALLED" ] && message "Error" "$_MYBATIS_DESCRIPTION is not installed!"

  _POSTGRESQL_HOST=$(input_field "gsan.postgresql.host" "Enter the host of the PostgreSQL Server" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_POSTGRESQL_HOST" ] && message "Alert" "The host of the PostgreSQL Server can not be blank!"

  _POSTGRESQL_PORT=$(input_field "gsan.postgresql.port" "Enter the port of the PostgreSQL Server" "5432")
  [ $? -eq 1 ] && main
  [ -z "$_POSTGRESQL_PORT" ] && message "Alert" "The port of the PostgreSQL Server can not be blank!"

  _POSTGRESQL_USER_NAME=$(input_field "gsan.postgresql.user.name" "Enter the user name of the PostgreSQL Server")
  [ $? -eq 1 ] && main
  [ -z "$_POSTGRESQL_USER_NAME" ] && message "Alert" "The user name of the PostgreSQL Server can not be blank!"

  _POSTGRESQL_USER_PASSWORD=$(input_field "gsan.postgresql.user.password" "Enter the user password of the PostgreSQL Server")
  [ $? -eq 1 ] && main
  [ -z "$_POSTGRESQL_USER_PASSWORD" ] && message "Alert" "The user password of the PostgreSQL Server can not be blank!"

  confirm "Do you confirm the install of GSAN Migrations?"
  [ $? -eq 1 ] && main

  tool_check git

  cd $_DEFAULT_PATH && git clone https://github.com/prodigasistemas/gsan-migracoes.git

  [ $? -ne 0 ] && message "Error" "Download of GSAN Migrations not realized!"

  _DATABASES="comercial gerencial"

  for database in $_DATABASES; do
    cd $_DEFAULT_PATH/gsan-migracoes/$database

    _PROPERTIES_FILE="environments/production.properties"

    cp environments/production.exemplo.properties $_PROPERTIES_FILE

    _SEARCH_CHARSET=$(cat $_PROPERTIES_FILE | egrep "^script_char_set")
    change_file "replace" "$_PROPERTIES_FILE" "$_SEARCH_CHARSET" "script_char_set=LATIN1"

    _SEARCH_URL=$(cat $_PROPERTIES_FILE | egrep "^url=jdbc:postgresql")
    change_file "replace" "$_PROPERTIES_FILE" "$_SEARCH_URL" "url=jdbc:postgresql://$_POSTGRESQL_HOST:$_POSTGRESQL_PORT/gsan_$database"

    _SEARCH_USERNAME=$(cat $_PROPERTIES_FILE | egrep "^username=")
    change_file "replace" "$_PROPERTIES_FILE" "$_SEARCH_USERNAME" "username=$_POSTGRESQL_USER_NAME"

    _SEARCH_PASSWORD=$(cat $_PROPERTIES_FILE | egrep "^password=")
    change_file "replace" "$_PROPERTIES_FILE" "$_SEARCH_PASSWORD" "password=$_POSTGRESQL_USER_PASSWORD"

    migrate status --env=production

    migrate up --env=production
  done

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "GSAN Migrations successfully installed!"
}

install_gsan () {
  _CURRENT_DIR=$(pwd)
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  java_check 6

  jboss_check 4

  _OWNER=$(input_field "jboss.config.owner" "Enter the JBoss owner name" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_OWNER" ] && message "Alert" "The JBoss owner name can not be blank!"

  confirm "Do you confirm the install of GSAN?"
  [ $? -eq 1 ] && main

  tool_check git
  tool_check ant

  cd $_DEFAULT_PATH && git clone https://github.com/prodigasistemas/gsan.git

  [ $? -ne 0 ] && message "Error" "Download of GSAN not realized!"

  _PROPERTIES_FILE="$_DEFAULT_PATH/gsan/build.properties"

  echo "jboss.home=$_DEFAULT_PATH/jboss" > $_PROPERTIES_FILE
  echo "jboss.deploy=$_DEFAULT_PATH/jboss/server/default/deploy" >> $_PROPERTIES_FILE
  echo "CaminhoReports=$_DEFAULT_PATH/gsan/reports" >> $_PROPERTIES_FILE
  echo "build.manifest=$_DEFAULT_PATH/gsan/MANIFEST.MF" >> $_PROPERTIES_FILE
  echo "gsan.tipo=Online" >> $_PROPERTIES_FILE
  echo "gsan.versao=1.0.0" >> $_PROPERTIES_FILE

  chown $_OWNER:$_OWNER -R $_DEFAULT_PATH/gsan

  run_as_user $_OWNER "JBOSS_HOME=$_DEFAULT_PATH/jboss /etc/init.d/jboss stop"

  run_as_user $_OWNER "export JBOSS_GSAN=$_DEFAULT_PATH/jboss"

  run_as_user $_OWNER "export GSAN_PATH=$(pwd)"

  run_as_user $_OWNER "cd $_DEFAULT_PATH/gsan && bash scripts/build/build_gcom.sh"

  run_as_user $_OWNER "JBOSS_HOME=$JBOSS_GSAN /etc/init.d/jboss start"

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "GSAN successfully installed!"
}

main () {
  [ "$_OS_ARCH" = "32" ] && _ARCH="i386"
  [ "$_OS_ARCH" = "64" ] && _ARCH="x64"

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_MAIN_OPTION" ]; then
      clear && exit 0
    else
      $_MAIN_OPTION
    fi
  else
    [ ! -z "$(search_app gsan.mybatis.version)" ] && install_mybatis
    [ ! -z "$(search_app gsan)" ] && install_gsan
  fi
}

setup
main
