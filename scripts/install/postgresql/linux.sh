#!/bin/bash
# http://www.postgresql.org
# https://wiki.postgresql.org/wiki/Apt
# https://wiki.postgresql.org/wiki/YUM_Installation
# https://www.vivaolinux.com.br/dica/Mudando-encoding-do-Postgres-84-para-LATIN1
# http://serverfault.com/questions/601140/whats-the-difference-between-sudo-su-postgres-and-sudo-u-postgres
# https://people.debian.org/~schultmc/locales.html
# http://progblog10.blogspot.com.br/2013/06/enabling-remote-access-to-postgresql.html
# http://www.thegeekstuff.com/2009/11/unix-sed-tutorial-append-insert-replace-and-count-file-lines/

_PACKAGE_COMMAND_DEBIAN="apt-get"
_PACKAGE_COMMAND_CENTOS="yum"
_OPTIONS_LIST="install_postgresql 'Install the database server' \
               configure_locale 'Set the locale for LATIN1 (pt_BR.ISO-8859-1)' \
               create_gsan_databases 'Create GSAN databases' \
               change_password 'Change password the user postgres' \
               remote_access 'Enable remote access'"

os_check () {
  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_DEBIAN
    _POSTGRESQL_VERSION=$(apt-cache show postgresql | grep Version | head -n 1 | cut -d: -f2 | cut -d+ -f1 | tr -d [:space:])
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_CENTOS
    _POSTGRESQL_VERSION=$(yum info postgresql | grep Version | head -n 1 | cut -d: -f2 | tr -d [:space:])
  fi

  _TITLE="--backtitle \"PostgreSQL $_POSTGRESQL_VERSION installation - OS: $_OS_NAME\""
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

change_file () {
  _CF_BACKUP=".backup-`date +"%Y%m%d%H%M%S%N"`"
  _CF_OPERATION=$1
  _CF_FILE=$2
  _CF_FROM=$3
  _CF_TO=$4

  case $_CF_OPERATION in
    replace)
      sed -i$_CF_BACKUP -e "s/$_CF_FROM/$_CF_TO/g" $_CF_FILE
      ;;
    append)
      sed -i$_CF_BACKUP -e "/$_CF_FROM/ a $_CF_TO" $_CF_FILE
      ;;
  esac
}

run_as_postgres () {
  su - postgres -c "$1"
}

run_as_root () {
  su -c "$1"
}

config_path () {
  if [ $_OS_TYPE = "deb" ]; then
    _PG_CONFIG_PATH="/etc/postgresql/$_POSTGRESQL_VERSION/main"
    _PG_METHOD_CHANGE="peer"
  elif [ $_OS_TYPE = "rpm" ]; then
    _PG_CONFIG_PATH="/var/lib/pgsql/data"
    _PG_METHOD_CHANGE="ident"
  fi
}

install_postgresql () {
  if [ $_OS_TYPE = "deb" ]; then
    dialog --yesno 'Configure PostgreSQL Apt Repository?' 0 0
    if [ $? = 0 ]; then
      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

      run_as_root "echo \"deb http://apt.postgresql.org/pub/repos/apt/ $_OS_CODENAME-pgdg main\" > /etc/apt/sources.list.d/postgresql.list"

      $_PACKAGE_COMMAND update
      os_check
    fi

    _VERSIONS_LIST=$(apt-cache search postgresql-server-dev | cut -d- -f4 | grep -v all | sort)
    _LAST_VERSION=$(echo $_VERSIONS_LIST | grep -oE "[^ ]+$")

    _POSTGRESQL_VERSION=$(input "Versions available: $_VERSIONS_LIST. Enter a version" "$_LAST_VERSION")
    [ $? -eq 1 ] && main
    [ -z "$_POSTGRESQL_VERSION" ] && message "Alert" "The version can not be blank!"
  fi

  dialog --yesno "Confirm the installation of PostgreSQL $_POSTGRESQL_VERSION?" 0 0
  [ $? = 1 ] && main

  if [ $_OS_TYPE = "deb" ]; then
    $_PACKAGE_COMMAND install -y postgresql-$_POSTGRESQL_VERSION postgresql-contrib-$_POSTGRESQL_VERSION postgresql-server-dev-$_POSTGRESQL_VERSION

  elif [ $_OS_TYPE = "rpm" ]; then
    $_PACKAGE_COMMAND install -y postgresql-server postgresql-contrib postgresql-devel
    service postgresql initdb
    service postgresql start
  fi

  message "Notice" "PostgreSQL successfully installed!"
}

configure_locale () {
  dialog --yesno 'Do you want to configure for LATIN1?' 0 0
  [ $? = 1 ] && main

  if [ $_OS_TYPE = "deb" ]; then
    if [ $_OS_NAME = "ubuntu" ]; then
      run_as_root "echo pt_BR ISO-8859-1 >> /var/lib/locales/supported.d/local"
      run_as_root "echo LANG=\"pt_BR\" >> /etc/environment"
      run_as_root "echo LANGUAGE=\"pt_BR:pt:en\" >> /etc/environment"
      run_as_root "echo LANG=\"pt_BR\" > /etc/default/locale"
      run_as_root "echo LANGUAGE=\"pt_BR:pt:en\" >> /etc/default/locale"
      run_as_root "echo \"pt_BR           pt_BR.ISO-8859-1\" >> /etc/locale.alias"

    elif [ $_OS_NAME = "debian" ]; then
      change_file "replace" "/etc/locale.gen" "# pt_BR ISO-8859-1" "pt_BR ISO-8859-1"
    fi

    locale-gen

    run_as_postgres "pg_dropcluster --stop $_POSTGRESQL_VERSION main"
    run_as_postgres "pg_createcluster --locale pt_BR.ISO-8859-1 --start $_POSTGRESQL_VERSION main"

  elif [ $_OS_TYPE = "rpm" ]; then
    service postgresql stop

    _PGSQL_FOLDER="/var/lib/pgsql"

    run_as_postgres "cp $_PGSQL_FOLDER/data/pg_hba.conf $_PGSQL_FOLDER/backups/"
    run_as_postgres "cp $_PGSQL_FOLDER/data/postgresql.conf $_PGSQL_FOLDER/backups/"

    run_as_postgres "rm -rf $_PGSQL_FOLDER/data/*"

    run_as_postgres "env LANG=LATIN1 /usr/bin/initdb --locale=pt_BR.iso88591 --encoding=LATIN1 -D $_PGSQL_FOLDER/data/"

    run_as_postgres "cp $_PGSQL_FOLDER/backups/pg_hba.conf $_PGSQL_FOLDER/data/"
    run_as_postgres "cp $_PGSQL_FOLDER/backups/postgresql.conf $_PGSQL_FOLDER/data/"

    service postgresql restart
  fi

  message "Notice" "LATIN1 locale configured successfully!"
}

create_gsan_databases () {
  dialog --yesno 'Do you confirm the creation of GSAN databases (gsan_comercial and gsan_gerencial) and tablespace indices?' 0 0
  [ $? = 1 ] && main

  if [ $_OS_TYPE = "deb" ]; then
    _POSTGRESQL_FOLDER="/var/lib/postgresql/$_POSTGRESQL_VERSION"
  elif [ $_OS_TYPE = "rpm" ]; then
    _POSTGRESQL_FOLDER="/var/lib/pgsql"
  fi

  _INDEX_FOLDER="$_POSTGRESQL_FOLDER/indices"

  run_as_postgres "mkdir $_INDEX_FOLDER"
  run_as_postgres "chmod 700 $_INDEX_FOLDER"
  run_as_postgres "createdb --encoding=LATIN1 --tablespace=pg_default -e gsan_comercial"
  run_as_postgres "createdb --encoding=LATIN1 --tablespace=pg_default -e gsan_gerencial"
  run_as_postgres "psql -c \"CREATE TABLESPACE indices LOCATION '$_INDEX_FOLDER';\""

  message "Notice" "GSAN databases created successfully!"
}

change_password () {
  _PASSWORD=$(input "Enter a new password for the user postgres" "postgres")
  [ $? -eq 1 ] && main
  [ -z "$_PASSWORD" ] && message "Alert" "The password can not be blank!"

  run_as_postgres "psql -c \"ALTER USER postgres WITH encrypted password '$_PASSWORD';\""

  config_path

  change_file "replace" "$_PG_CONFIG_PATH/pg_hba.conf" "$_PG_METHOD_CHANGE$" "md5"

  service postgresql restart

  message "Notice" "Password changed successfully!"
}

remote_access () {
  dialog --yesno 'Do you want to enable remote access?' 0 0
  [ $? = 1 ] && main

  config_path

  change_file "append" "$_PG_CONFIG_PATH/pg_hba.conf" "^# IPv4 local connections:" "host    all             all             0.0.0.0/0               md5"

  change_file "replace" "$_PG_CONFIG_PATH/postgresql.conf" "^#listen_addresses = 'localhost'" "listen_addresses = '*'"

  service postgresql restart

  message "Notice" "Enabling remote access successfully held!"
}

main () {
  tool_check wget
  tool_check dialog

  _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_OPTION" ]; then
    clear
    exit 0
  else
    $_OPTION
  fi
}

os_check
main
