#!/bin/bash
# http://www.postgresql.org
# https://wiki.postgresql.org/wiki/Apt
# https://wiki.postgresql.org/wiki/YUM_Installation
# https://www.vivaolinux.com.br/dica/Mudando-encoding-do-Postgres-84-para-LATIN1
# http://serverfault.com/questions/601140/whats-the-difference-between-sudo-su-postgres-and-sudo-u-postgres
# https://people.debian.org/~schultmc/locales.html

_PACKAGE_COMMAND_DEBIAN="apt-get"
_PACKAGE_COMMAND_CENTOS="yum"
_OPTIONS_LIST="install_postgresql 'Install the database server' configure_locale 'Set the locale for LATIN1 (pt_BR.ISO-8859-1)' create_gsan_databases 'Create GSAN databases' change_password 'Change password the user postgres'"

os_check () {
  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_DEBIAN
    _POSTGRESQL_VERSION=$(apt-cache show postgresql | grep Version | head -n 1 | cut -d: -f2 | cut -d+ -f1 | tr -d [:space:])
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_CENTOS
    _POSTGRESQL_VERSION=$(yum info postgresql | grep Version | head -n 1 | cut -d: -f2 | tr -d [:space:])
  fi

  _TITLE="--backtitle \"PostgreSQL $_POSTGRESQL_VERSION installation - OS: $_OS_NAME\""
}

dialog_check () {
  echo "Checking for dialog..."
  if command -v dialog > /dev/null; then
    echo "Detected dialog..."
  else
    echo "Installing dialog..."
    $_PACKAGE_COMMAND install -y dialog
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
}

change_file () {
  _BACKUP=".backup-`date +"%Y%m%d%H%M%S"`"

  sed -i$_BACKUP -e "s/$2/$3/g" $1
}

run_as_postgres () {
  su - postgres -c "$1"
}

run_as_root () {
  su -c "$1"
}

install_postgresql () {
  dialog --yesno 'Confirm the installation of PostgreSQL?' 0 0
  [ $? = 1 ] && main

  if [ $_OS_TYPE = "deb" ]; then
    $_PACKAGE_COMMAND update
    $_PACKAGE_COMMAND install -y postgresql-$_POSTGRESQL_VERSION postgresql-contrib-$_POSTGRESQL_VERSION postgresql-server-dev-$_POSTGRESQL_VERSION

  elif [ $_OS_TYPE = "rpm" ]; then
    $_PACKAGE_COMMAND install -y postgresql-server postgresql-contrib postgresql-devel
    service postgresql initdb
    service postgresql start
  fi

  message "Notice" "PostgreSQL successfully installed!"
  main
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
      change_file "/etc/locale.gen" "# pt_BR ISO-8859-1" "pt_BR ISO-8859-1"
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
  main
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
  main
}

change_password () {
  if [ $_OS_TYPE = "deb" ]; then
    _HBA_PATH="/etc/postgresql/$_POSTGRESQL_VERSION/main"
    _METHOD_CHANGE="peer"
  elif [ $_OS_TYPE = "rpm" ]; then
    _HBA_PATH="/var/lib/pgsql/data"
    _METHOD_CHANGE="ident"
  fi

  _PASSWORD=$(input "Enter a new password for the user postgres" "postgres")
  [ $? = 1 ] && main

  if [ -z "$_PASSWORD" ]; then
    message "Alert" "The password can not be blank!"
    main
  fi

  run_as_postgres "psql -c \"ALTER USER postgres WITH encrypted password '$_PASSWORD';\""

  change_file "$_HBA_PATH/pg_hba.conf" "$_METHOD_CHANGE$" "md5"

  service postgresql restart

  message "Notice" "Password changed successfully!"
  main
}

main () {
  _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_OPTION" ]; then
    clear
    exit 0
  else
    $_OPTION
  fi
}

os_check
dialog_check
main
