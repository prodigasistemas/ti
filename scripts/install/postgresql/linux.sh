#!/bin/bash
# http://www.postgresql.org
# https://wiki.postgresql.org/wiki/Apt
# https://wiki.postgresql.org/wiki/YUM_Installation
# https://www.vivaolinux.com.br/dica/Mudando-encoding-do-Postgres-84-para-LATIN1

_PACKAGE_COMMAND_DEBIAN="apt-get"
_PACKAGE_COMMAND_CENTOS="yum"
_OPTIONS_LIST="install_postgresql 'Install the database server' configure_locale 'Set the locale for LATIN1' create_gsan_databases 'Create GSAN databases'"

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
    $_PACKAGE_COMMAND install -q -y dialog
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

  sed -i$_BACKUP -e "s/$1/$2/g" $3
}

input_postgresql_password () {
  _PASSWORD=$(input "Enter a password for the user postgres" "postgres")
  if [ -z "$_PASSWORD" ]; then
    message "Alert" "The password can not be blank!"
    exit 1
  fi
}

change_postgresql_password () {
  psql -c "ALTER USER postgres WITH encrypted password '$_PASSWORD';"
}

install_postgresql () {
  dialog --yesno 'Confirm the installation of PostgreSQL?' 0 0
  [ $? = 1 ] && exit 1

  input_postgresql_password

  if [ $_OS_TYPE = "deb" ]; then
    _HBA_PATH="/etc/postgresql/$_POSTGRESQL_VERSION/main"
    _METHOD_CHANGE="peer"

    $_PACKAGE_COMMAND update
    $_PACKAGE_COMMAND install -y postgresql-$_POSTGRESQL_VERSION postgresql-contrib-$_POSTGRESQL_VERSION postgresql-server-dev-$_POSTGRESQL_VERSION

  elif [ $_OS_TYPE = "rpm" ]; then
    _HBA_PATH="/var/lib/pgsql/data"
    _METHOD_CHANGE="ident"

    $_PACKAGE_COMMAND install -y postgresql-server postgresql-contrib postgresql-devel
    service postgresql initdb
    service postgresql start
  fi

  su postgres

  change_postgresql_password

  change_file "$_METHOD_CHANGE$" "md5" "$_HBA_PATH/pg_hba.conf"

  service postgresql restart
}

configure_locale () {
  dialog --yesno 'You want to configure for LATIN1 ( pt_BR.ISO-8859-1 )?' 0 0
  [ $? = 1 ] && exit 1

  if [ $_OS_TYPE = "deb" ]; then
    echo 'pt_BR ISO-8859-1' >> /var/lib/locales/supported.d/local # not found in debian

    echo 'LANG="pt_BR"' >> /etc/environment
    echo 'LANGUAGE="pt_BR:pt:en"' >> /etc/environment

    echo 'LANG="pt_BR"' > /etc/default/locale
    echo 'LANGUAGE="pt_BR:pt:en"' >> /etc/default/locale

    echo 'pt_BR           pt_BR.ISO-8859-1' >> /etc/locale.alias

    locale-gen

    pg_dropcluster --stop $_POSTGRESQL_VERSION main

    pg_createcluster --locale pt_BR.ISO-8859-1 --start $_POSTGRESQL_VERSION main

  elif [ $_OS_TYPE = "rpm" ]; then
    cd /var/lib/pgsql/data
    cp -a pg_hba.conf postgresql.conf ../backups

    /etc/init.d/postgresql stop

    cd /var/lib/pgsql/
    rm -rf data/*

    su postgres

    env LANG=LATIN1 /usr/bin/initdb --locale=pt_BR.iso88591 --encoding=LATIN1 -D /var/lib/pgsql/data/

    cd /var/lib/pgsql/backups
    cp -a pg_hba.conf postgresql.conf ../data

    /etc/init.d/postgresql restart

    input_postgresql_password

    change_postgresql_password

  fi

  dialog --yesno 'You will need to restart the server, you confirm?' 0 0
  [ $? = 0 ] && reboot
}

create_gsan_databases () {
  dialog --yesno 'You confirm the creation of GSAN databases (gsan_comercial and gsan_gerencial) and tablespace indices ?' 0 0
  [ $? = 1 ] && exit 1

  if [ $_OS_TYPE = "deb" ]; then
    _POSTGRESQL_FOLDER="/var/lib/postgresql/$_POSTGRESQL_VERSION"
  elif [ $_OS_TYPE = "rpm" ]; then
    _POSTGRESQL_FOLDER="/var/lib/pgsql"
  fi

  su - postgres

  mkdir "$_POSTGRESQL_FOLDER/indices"
  chmod 700 "$_POSTGRESQL_FOLDER/indices"

  createdb --encoding=LATIN1 --tablespace=pg_default -e gsan_comercial
  createdb --encoding=LATIN1 --tablespace=pg_default -e gsan_gerencial

  psql -c "CREATE TABLESPACE indices LOCATION '$_POSTGRESQL_FOLDER/indices';"

  input_postgresql_password

  change_postgresql_password
}

main () {
  os_check
  dialog_check

  _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  [ $? -eq 0 ] && $_OPTION
}

main
