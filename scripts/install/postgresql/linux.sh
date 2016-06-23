#!/bin/bash
# http://www.postgresql.org
# https://wiki.postgresql.org/wiki/Apt
# https://wiki.postgresql.org/wiki/YUM_Installation
# https://www.vivaolinux.com.br/dica/Mudando-encoding-do-Postgres-84-para-LATIN1
# http://serverfault.com/questions/601140/whats-the-difference-between-sudo-su-postgres-and-sudo-u-postgres
# https://people.debian.org/~schultmc/locales.html
# http://progblog10.blogspot.com.br/2013/06/enabling-remote-access-to-postgresql.html

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
    _PG_METHOD_CHANGE="peer"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _PG_CONFIG_PATH="/var/lib/pgsql/data"
    _PG_METHOD_CHANGE="ident"
  fi
}

install_postgresql_server () {
  if [ "$_OS_TYPE" = "deb" ]; then
    confirm "Configure PostgreSQL Apt Repository?"
    if [ $? -eq 0 ]; then
      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

      run_as_root "echo \"deb http://apt.postgresql.org/pub/repos/apt/ $_OS_CODENAME-pgdg main\" > /etc/apt/sources.list.d/postgresql.list"

      $_PACKAGE_COMMAND update
      os_check
    fi

    _VERSIONS_LIST=$(apt-cache search postgresql-server-dev | cut -d- -f4 | grep -v all | sort)
    _LAST_VERSION=$(echo $_VERSIONS_LIST | grep -oE "[^ ]+$")

    _POSTGRESQL_VERSION=$(input_field "postgresql.server.version" "Versions available: $_VERSIONS_LIST. Enter a version" "$_LAST_VERSION")
    [ $? -eq 1 ] && main
    [ -z "$_POSTGRESQL_VERSION" ] && message "Alert" "The PostgreSQL version can not be blank!"
  fi

  confirm "Confirm the installation of PostgreSQL $_POSTGRESQL_VERSION?"
  [ $? = 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    $_PACKAGE_COMMAND install -y postgresql-$_POSTGRESQL_VERSION postgresql-contrib-$_POSTGRESQL_VERSION postgresql-server-dev-$_POSTGRESQL_VERSION

  elif [ "$_OS_TYPE" = "rpm" ]; then
    #TODO: get updated versions
    $_PACKAGE_COMMAND install -y postgresql-server postgresql-contrib postgresql-devel
    service postgresql initdb
    service postgresql start
  fi

  [ $? -eq 0 ] && message "Notice" "PostgreSQL $_POSTGRESQL_VERSION successfully installed!"
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
  _PASSWORD=$(input_field "postgresql.server.postgres.password" "Enter a new password for the user postgres" "postgres")
  [ $? -eq 1 ] && main
  [ -z "$_PASSWORD" ] && message "Alert" "The password can not be blank!"

  run_as_postgres "psql -c \"ALTER USER postgres WITH ENCRYPTED PASSWORD '$_PASSWORD';\""

  config_path

  change_file "replace" "$_PG_CONFIG_PATH/pg_hba.conf" "$_PG_METHOD_CHANGE$" "md5"

  service postgresql restart

  [ $? -eq 0 ] && message "Notice" "Password changed successfully!"
}

remote_access () {
  confirm "Do you want to enable remote access?"
  [ $? -eq 1 ] && main

  config_path

  change_file "append" "$_PG_CONFIG_PATH/pg_hba.conf" "^# IPv4 local connections:" "host    all             all             0.0.0.0/0               md5"

  change_file "replace" "$_PG_CONFIG_PATH/postgresql.conf" "^#listen_addresses = 'localhost'" "listen_addresses = '*'"

  service postgresql restart

  [ $? -eq 0 ] && message "Notice" "Enabling remote access successfully held!"
}

main () {
  tool_check wget
  tool_check dialog

  [ "$_OS_TYPE" = "deb" ] && _POSTGRESQL_VERSION=$(apt-cache show postgresql | grep Version | head -n 1 | cut -d: -f2 | cut -d+ -f1 | tr -d [:space:])
  [ "$_OS_TYPE" = "rpm" ] && _POSTGRESQL_VERSION=$(yum info postgresql | grep Version | head -n 1 | cut -d: -f2 | tr -d [:space:])

  if [ "$(provisioning)" = "manual" ]; then
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
