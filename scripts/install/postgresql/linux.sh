#!/bin/bash
# http://www.postgresql.org
# https://wiki.postgresql.org/wiki/Apt
# https://wiki.postgresql.org/wiki/YUM_Installation
# https://www.vivaolinux.com.br/dica/Mudando-encoding-do-Postgres-84-para-LATIN1
# http://serverfault.com/questions/601140/whats-the-difference-between-sudo-su-postgres-and-sudo-u-postgres
# https://people.debian.org/~schultmc/locales.html
# http://progblog10.blogspot.com.br/2013/06/enabling-remote-access-to-postgresql.html
# http://dba.stackexchange.com/questions/14740/how-to-use-psql-with-no-password-prompt
# https://wiki.postgresql.org/wiki/YUM_Installation
# https://www.unixmen.com/postgresql-9-4-released-install-centos-7/

_APP_NAME="PostgreSQL"
_OPTIONS_LIST="install_postgresql_server 'Install the database server' \
               install_postgresql_client 'Install the database client' \
               change_password 'Change password the user postgres' \
               remote_access 'Enable remote access'"

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

config_path () {
  if [ "$_OS_TYPE" = "deb" ]; then
    _PG_CONFIG_PATH="/etc/postgresql/$_POSTGRESQL_VERSION/main"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _PG_CONFIG_PATH="/var/lib/pgsql/$_POSTGRESQL_VERSION/data"
  fi
}

install_postgresql_server () {
  if [ "$_OS_TYPE" = "deb" ]; then
    _PG_SOURCE_FILE="/etc/apt/sources.list.d/postgresql.list"

    if [ ! -e "$_PG_SOURCE_FILE" ]; then
      tool_check wget

      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

      run_as_root "echo \"deb http://apt.postgresql.org/pub/repos/apt/ $_OS_CODENAME-pgdg main\" > $_PG_SOURCE_FILE"

      $_PACKAGE_COMMAND update
    fi

    _VERSIONS_LIST=$(apt-cache search postgresql-server-dev | cut -d- -f4 | grep -v all | sort | sed 's/\ /;/g')

  elif [ "$_OS_TYPE" = "rpm" ]; then
    _VERSIONS_LIST="9.3; 9.4; 9.5; "

  fi

  _LAST_VERSION=$(echo $_VERSIONS_LIST | grep -oE "[^ ]+$" | sed 's/;//g')

  _POSTGRESQL_VERSION=$(input_field "postgresql.server.version" "Versions available: $_VERSIONS_LIST Enter a version" "$_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_POSTGRESQL_VERSION" ] && message "Alert" "The PostgreSQL version can not be blank!"

  _VERSION_VALID=$(echo $_VERSIONS_LIST | egrep "$_POSTGRESQL_VERSION;")
  [ -z "$_VERSION_VALID" ] && message "Alert" "PostgreSQL version invalid!"

  confirm "Confirm the installation of PostgreSQL $_POSTGRESQL_VERSION Server?"
  [ $? -eq 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    $_PACKAGE_COMMAND install -y postgresql-$_POSTGRESQL_VERSION postgresql-contrib-$_POSTGRESQL_VERSION postgresql-server-dev-$_POSTGRESQL_VERSION

  elif [ "$_OS_TYPE" = "rpm" ]; then
    [ "$_OS_ARCH" = "32" ] && _ARCH="i386"
    [ "$_OS_ARCH" = "64" ] && _ARCH="x86_64"

    _POSTGRESQL_VERSION_COMPACT=$(echo $_POSTGRESQL_VERSION | sed 's/\.//g')

    yum install -y "http://yum.postgresql.org/$_POSTGRESQL_VERSION/redhat/rhel-$_OS_RELEASE-$_ARCH/pgdg-centos$_POSTGRESQL_VERSION_COMPACT-$_POSTGRESQL_VERSION-2.noarch.rpm"

    $_PACKAGE_COMMAND install -y postgresql$_POSTGRESQL_VERSION_COMPACT-server postgresql$_POSTGRESQL_VERSION_COMPACT-contrib postgresql$_POSTGRESQL_VERSION_COMPACT-devel

    if [ "$_OS_RELEASE" -le 6 ]; then
      service postgresql-$_POSTGRESQL_VERSION initdb
    else
      /usr/pgsql-$_POSTGRESQL_VERSION/bin/postgresql$_POSTGRESQL_VERSION_COMPACT-setup initdb
    fi

    admin_service postgresql-$_POSTGRESQL_VERSION register

    admin_service postgresql-$_POSTGRESQL_VERSION start
  fi

  [ $? -eq 0 ] && message "Notice" "PostgreSQL $_POSTGRESQL_VERSION Server successfully installed!"
}

install_postgresql_client () {
  confirm "Confirm the installation of PostgreSQL $_POSTGRESQL_VERSION Client?"
  [ $? -eq 1 ] && main

  [ "$_OS_TYPE" = "deb" ] && _PACKAGE="postgresql-client-$_POSTGRESQL_VERSION"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGE="postgresql"

  $_PACKAGE_COMMAND -y install $_PACKAGE

  [ $? -eq 0 ] && message "Notice" "PostgreSQL $_POSTGRESQL_VERSION Client successfully installed!"
}

change_password () {
  _OLD_PASSWORD=$(input_field "[default]" "Enter a old password for the user postgres")
  [ $? -eq 1 ] && main

  _NEW_PASSWORD=$(input_field "postgresql.server.postgres.password" "Enter a new password for the user postgres")
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

  [ $? -eq 0 ] && message "Notice" "Password changed successfully!"
}

remote_access () {
  confirm "Do you want to enable remote access?"
  [ $? -eq 1 ] && main

  config_path

  change_file "append" "$_PG_CONFIG_PATH/pg_hba.conf" "^# IPv4 local connections:" "host    all             all             0.0.0.0/0               md5"

  change_file "replace" "$_PG_CONFIG_PATH/postgresql.conf" "^#listen_addresses = 'localhost'" "listen_addresses = '*'"

  [ "$_OS_TYPE" = "rpm" ] && _SERVICE_VERSION="-$_POSTGRESQL_VERSION"

  admin_service postgresql$_SERVICE_VERSION restart

  [ $? -eq 0 ] && message "Notice" "Enabling remote access successfully held!"
}

main () {
  _POSTGRESQL_VERSION=$(postgres_version)

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ ! -z "$(search_app postgresql.server.version)" ] && install_postgresql_server
    [ ! -z "$(search_app postgresql.client.version)" ] && install_postgresql_client
    [ ! -z "$(search_app postgresql.server.postgres.password)" ] && change_password
    [ "$(search_value postgresql.server.remote.access)" = "yes" ] && remote_access
  fi
}

setup
main
