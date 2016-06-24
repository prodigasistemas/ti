#!/bin/bash

# https://github.com/prodigasistemas/gsan
# http://www.mybatis.org/migrations/
# https://github.com/mybatis/migrations/releases
# http://stackoverflow.com/questions/4262374/failed-to-create-task-or-type-propertyfile-ant-build

_APP_NAME="GSAN"
_DEFAULT_PATH="/opt"
_MYBATIS_VERSION="3.2.1"
_MYBATIS_DESCRIPTION="MyBatis Migration"
_OPTIONS_LIST="configure_locale_latin 'Set the locale for LATIN1 (pt_BR.ISO-8859-1)' \
               change_postgres_password 'Change password the user postgres' \
               configure_datasource 'Datasource configuration' \
               create_gsan_databases 'Create GSAN databases' \
               install_mybatis_migration 'Install $_MYBATIS_DESCRIPTION' \
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

input_datas () {
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
}

configure_locale_latin () {
  _POSTGRESQL_INSTALLED=$(run_as_user $_USER_LOGGED "command -v psql")
  [ -z "$_POSTGRESQL_INSTALLED" ] && message "Error" "PostgreSQL Server is not installed!"

  confirm "Do you want to configure locale for LATIN1?"
  [ $? -eq 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    if [ "$_OS_NAME" = "ubuntu" ]; then
      run_as_root "echo pt_BR ISO-8859-1 >> /var/lib/locales/supported.d/local"
      run_as_root "echo LANG=\"pt_BR\" >> /etc/environment"
      run_as_root "echo LANGUAGE=\"pt_BR:pt:en\" >> /etc/environment"
      run_as_root "echo LANG=\"pt_BR\" > /etc/default/locale"
      run_as_root "echo LANGUAGE=\"pt_BR:pt:en\" >> /etc/default/locale"
      run_as_root "echo \"pt_BR           pt_BR.ISO-8859-1\" >> /etc/locale.alias"

    elif [ "$_OS_NAME" = "debian" ]; then
      change_file "replace" "/etc/locale.gen" "# pt_BR ISO-8859-1" "pt_BR ISO-8859-1"

    fi

    locale-gen

    run_as_postgres "pg_dropcluster --stop $_POSTGRESQL_VERSION main"
    run_as_postgres "pg_createcluster --locale pt_BR.ISO-8859-1 --start $_POSTGRESQL_VERSION main"

  elif [ "$_OS_TYPE" = "rpm" ]; then
    admin_service postgresql-$_POSTGRESQL_VERSION stop

    _PGSQL_FOLDER="/var/lib/pgsql/$_POSTGRESQL_VERSION"

    run_as_postgres "rm -rf $_PGSQL_FOLDER/data/*"

    if [ "$_OS_RELEASE" -le 6 ]; then
      run_as_postgres "env LANG=LATIN1 /usr/pgsql-$_POSTGRESQL_VERSION/bin/initdb --locale=pt_BR.iso88591 --encoding=LATIN1 -D $_PGSQL_FOLDER/data/"
    else
      run_as_postgres "env LANG=LATIN1 /usr/pgsql-$_POSTGRESQL_VERSION/bin/postgresql$_POSTGRESQL_VERSION_COMPACT-setup initdb --locale=pt_BR.iso88591 --encoding=LATIN1 -D $_PGSQL_FOLDER/data/"
    fi

    [ "$_OS_TYPE" = "rpm" ] && _SERVICE_VERSION="-$_POSTGRESQL_VERSION"

    admin_service postgresql$_SERVICE_VERSION restart
  fi

  [ $? -eq 0 ] && message "Notice" "LATIN1 locale configured successfully!"
}

configure_datasource () {
  jboss_check 4

  input_datas

  confirm "Host: $_POSTGRESQL_HOST\nPort: $_POSTGRESQL_PORT\nUser: $_POSTGRESQL_USER_NAME\nPassword: $_POSTGRESQL_USER_PASSWORD\nDo you confirm the configuration of Datasource?"
  [ $? -eq 1 ] && main

  curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/gsan/postgres-ds.xml" > postgres-ds.xml

  change_file replace postgres-ds.xml HOST $_POSTGRESQL_HOST
  change_file replace postgres-ds.xml PORT $_POSTGRESQL_PORT
  change_file replace postgres-ds.xml USERNAME $_POSTGRESQL_USER_NAME
  change_file replace postgres-ds.xml PASSWORD $_POSTGRESQL_USER_PASSWORD

  mv postgres-ds.xml $_DEFAULT_PATH/jboss/server/default/deploy/
  rm postgres-ds.xml*

  [ $? -eq 0 ] && message "Notice" "Datasource successfully configured!"
}

create_gsan_databases () {
  _POSTGRESQL_INSTALLED=$(run_as_user $_USER_LOGGED "command -v psql")
  [ -z "$_POSTGRESQL_INSTALLED" ] && message "Error" "PostgreSQL Server is not installed!"

  _PASSWORD=$(input_field "gsan.postgresql.user.password" "Enter a password for the user postgres")
  [ $? -eq 1 ] && main
  [ ! -z "$_PASSWORD" ] && _INFORM_PASSWORD="PGPASSWORD=$_PASSWORD"

  confirm "Do you confirm the creation of GSAN databases (gsan_comercial and gsan_gerencial) and tablespace indices?"
  [ $? -eq 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    _POSTGRESQL_FOLDER="/var/lib/postgresql/$_POSTGRESQL_VERSION"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _POSTGRESQL_FOLDER="/var/lib/pgsql/$_POSTGRESQL_VERSION"
  fi

  _INDEX_FOLDER="$_POSTGRESQL_FOLDER/indices"

  run_as_postgres "rm -rf $_INDEX_FOLDER"
  run_as_postgres "mkdir $_INDEX_FOLDER"
  run_as_postgres "chmod 700 $_INDEX_FOLDER"
  run_as_postgres "$_INFORM_PASSWORD createdb --encoding=LATIN1 --tablespace=pg_default -e gsan_comercial"
  run_as_postgres "$_INFORM_PASSWORD createdb --encoding=LATIN1 --tablespace=pg_default -e gsan_gerencial"
  run_as_postgres "$_INFORM_PASSWORD psql -c \"CREATE TABLESPACE indices LOCATION '$_INDEX_FOLDER';\""

  [ $? -eq 0 ] && message "Notice" "GSAN databases created successfully!"
}

config_path () {
  if [ "$_OS_TYPE" = "deb" ]; then
    _PG_CONFIG_PATH="/etc/postgresql/$_POSTGRESQL_VERSION/main"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _PG_CONFIG_PATH="/var/lib/pgsql/$_POSTGRESQL_VERSION/data"
  fi
}

change_postgres_password () {
  _OLD_PASSWORD=$(input_field "[default]" "Enter a old password for the user postgres")
  [ $? -eq 1 ] && main

  _NEW_PASSWORD=$(input_field "gsan.postgresql.user.password" "Enter a new password for the user postgres")
  [ $? -eq 1 ] && main
  [ -z "$_NEW_PASSWORD" ] && message "Alert" "The password can not be blank!"

  [ ! -z "$_OLD_PASSWORD" ] && _INFORM_PASSWORD="PGPASSWORD=$_OLD_PASSWORD"

  confirm "Confirm change postgres password?"
  [ $? -eq 1 ] && main

  run_as_postgres "${_INFORM_PASSWORD} psql -c \"ALTER USER postgres WITH ENCRYPTED PASSWORD '$_NEW_PASSWORD';\""

  config_path

  change_file "replace" "$_PG_CONFIG_PATH/pg_hba.conf" "ident$" "md5"
  change_file "replace" "$_PG_CONFIG_PATH/pg_hba.conf" "trust$" "md5"
  change_file "replace" "$_PG_CONFIG_PATH/pg_hba.conf" "peer$" "md5"

  [ "$_OS_TYPE" = "rpm" ] && _SERVICE_VERSION="-$_POSTGRESQL_VERSION"

  admin_service postgresql$_SERVICE_VERSION restart

  [ $? -eq 0 ] && message "Notice" "postgres password changed successfully!"
}

install_mybatis_migration () {
  _CURRENT_DIR=$(pwd)

  java_check 6

  [ -z "$JAVA_HOME" ] && JAVA_HOME="/usr/lib/jvm/java-6-openjdk-$_ARCH"
  [ ! -e "$JAVA_HOME" ] && JAVA_HOME="/usr/lib/jvm/java-1.6.0"
  [ ! -e "$JAVA_HOME" ] && JAVA_HOME="/opt/jdk1.6.0_45"

  _VERSION=$(input_field "gsan.mybatis.migrations.version" "Enter the $_MYBATIS_DESCRIPTION version" "$_MYBATIS_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && message "Alert" "The $_MYBATIS_DESCRIPTION version can not be blank!"

  _JAVA_HOME=$(input_field "[default]" "Enter the JAVA_HOME path" "$JAVA_HOME")
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

  ln -sf $_MYBATIS_JAR_FILE $_JAVA_HOME/jre/lib/ext/

  ln -sf $_DEFAULT_PATH/mybatis-migrations/lib/$_MYBATIS_FILE.jar $_JAVA_HOME/jre/lib/ext/

  ln -sf $_DEFAULT_PATH/mybatis-migrations/bin/migrate /usr/local/bin

  cd $_CURRENT_DIR

  run_as_user $_USER_LOGGED "migrate info"

  [ $? -eq 0 ] && message "Notice" "$_MYBATIS_DESCRIPTION $_VERSION successfully installed!"
}

install_gsan_migrations () {
  _CURRENT_DIR=$(pwd)

  _POSTGRESQL_INSTALLED=$(run_as_user $_USER_LOGGED "command -v psql")
  [ -z "$_POSTGRESQL_INSTALLED" ] && message "Error" "PostgreSQL Client or Server is not installed!"

  _MYBATIS_INSTALLED=$(run_as_user $_USER_LOGGED "command -v migrate")
  [ -z "$_MYBATIS_INSTALLED" ] && message "Error" "$_MYBATIS_DESCRIPTION is not installed!"

  input_datas

  confirm "Host: $_POSTGRESQL_HOST\nPort: $_POSTGRESQL_PORT\nUser: $_POSTGRESQL_USER_NAME\nPassword: $_POSTGRESQL_USER_PASSWORD\nDo you confirm the install of GSAN Migrations?"
  [ $? -eq 1 ] && main

  tool_check git

  delete_file $_DEFAULT_PATH/gsan-migracoes

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

    run_as_user $_USER_LOGGED "cd $_DEFAULT_PATH/gsan-migracoes/$database && migrate status --env=production"

    run_as_user $_USER_LOGGED "cd $_DEFAULT_PATH/gsan-migracoes/$database && migrate up --env=production"
  done

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "GSAN Migrations successfully installed!"
}

install_gsan () {
  _CURRENT_DIR=$(pwd)

  java_check 6

  jboss_check 4

  [ ! -e "/etc/init.d/jboss" ] && message "Alert" "JBoss 4 is not configured!"

  _OWNER=$(input_field "jboss.config.owner" "Enter the JBoss owner name" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_OWNER" ] && message "Alert" "The JBoss owner name can not be blank!"

  confirm "Do you confirm the install of GSAN?"
  [ $? -eq 1 ] && main

  tool_check git
  tool_check ant
  [ "$_OS_TYPE" = "rpm" ] && tool_check ant-nodeps

  cd $_DEFAULT_PATH

  if [ ! -e "$_DEFAULT_PATH/gsan" ]; then
    git clone https://github.com/prodigasistemas/gsan.git

    [ $? -ne 0 ] && message "Error" "Download of GSAN not realized!"
  fi

  _PROPERTIES_FILE="$_DEFAULT_PATH/gsan/build.properties"

  echo "jboss.home=$_DEFAULT_PATH/jboss" > $_PROPERTIES_FILE
  echo "jboss.deploy=$_DEFAULT_PATH/jboss/server/default/deploy" >> $_PROPERTIES_FILE
  echo "CaminhoReports=$_DEFAULT_PATH/gsan/reports" >> $_PROPERTIES_FILE
  echo "build.manifest=$_DEFAULT_PATH/gsan/MANIFEST.MF" >> $_PROPERTIES_FILE
  echo "gsan.tipo=Online" >> $_PROPERTIES_FILE
  echo "gsan.versao=1.0.0" >> $_PROPERTIES_FILE

  chown $_OWNER:$_OWNER -R $_DEFAULT_PATH/gsan

  run_as_user $_OWNER "JBOSS_HOME=$_DEFAULT_PATH/jboss /etc/init.d/jboss stop"

  run_as_user $_OWNER "cd $_DEFAULT_PATH/gsan && JBOSS_GSAN=$_DEFAULT_PATH/jboss GSAN_PATH=$_DEFAULT_PATH/gsan bash scripts/build/build_gcom.sh"

  run_as_user $_OWNER "JBOSS_HOME=$JBOSS_GSAN /etc/init.d/jboss start"

  cd $_CURRENT_DIR

  [ $? -eq 0 ] && message "Notice" "GSAN successfully installed!"
}

main () {
  [ "$_OS_ARCH" = "32" ] && _ARCH="i386"
  [ "$_OS_ARCH" = "64" ] && _ARCH="amd64"

  _POSTGRESQL_VERSION=$(postgres_version)
  _POSTGRESQL_VERSION_COMPACT=$(echo $_POSTGRESQL_VERSION | sed 's/\.//g')

  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_MAIN_OPTION" ]; then
      clear && exit 0
    else
      $_MAIN_OPTION
    fi
  else
    [ "$(search_value gsan.configure.locale.latin)" = "yes" ] && configure_locale_latin
    [ ! -z "$(search_app gsan.postgresql.user.password)" ] && change_postgres_password
    if [ "$(search_value gsan.create.databases)" = "yes" ]; then
      configure_datasource
      create_gsan_databases
    fi
    [ ! -z "$(search_app gsan.mybatis.migrations.version)" ] && install_mybatis_migration
    [ "$(search_value gsan.install.migrations)" = "yes" ] && install_gsan_migrations
    [ ! -z "$(search_app gsan)" ] && install_gsan
  fi
}

setup
main
