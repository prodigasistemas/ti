#!/bin/bash
# http://www.postgresql.org
# https://wiki.postgresql.org/wiki/Apt
# https://wiki.postgresql.org/wiki/YUM_Installation

_PACKAGE_COMMAND_DEBIAN="apt-get"
_PACKAGE_COMMAND_CENTOS="yum"

os_check () {
  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_DEBIAN
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_CENTOS
  fi

  _TITLE="--backtitle \"PostgreSQL installation - OS: $_OS_NAME\""
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

password () {
  echo $(eval dialog $_TITLE --stdout --passwordbox \"$1\" 0 0)
}

change_file() {
  _BACKUP=".backup-`date +"%Y%m%d%H%M%S"`"

  sed -i$_BACKUP -e "s/$1/$2/g" $3
}

install_postgresql () {
  if [ $_OS_TYPE = "deb" ]; then
    _VERSION=$(apt-cache search postgresql-server-dev | grep programming | cut -d"-" -f4 | tr -d [:space:])
    _HBA_PATH="/etc/postgresql/$_VERSION/main"
    _METHOD_CHANGE="peer"

    $_PACKAGE_COMMAND update
    $_PACKAGE_COMMAND install -y postgresql-$_VERSION postgresql-contrib-$_VERSION postgresql-server-dev-$_VERSION

  elif [ $_OS_TYPE = "rpm" ]; then
    _HBA_PATH="/var/lib/pgsql/data"
    _METHOD_CHANGE="ident"

    $_PACKAGE_COMMAND install -y postgresql-server postgresql-contrib postgresql-devel
    service postgresql initdb
    service postgresql start
  fi

  su postgres
  psql -c "ALTER USER postgres WITH encrypted password '$_PASSWORD';"
  exit

  change_file "$_METHOD_CHANGE$" "md5" "$_HBA_PATH/pg_hba.conf"

  service postgresql restart
}

main () {
  os_check
  dialog_check

  _PASSWORD=$(password "Enter a new password for the user postgres")
  [ -z "$_PASSWORD" ] && exit 1

  install_postgresql
}
