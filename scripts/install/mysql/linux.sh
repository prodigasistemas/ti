#!/bin/bash
# https://easyengine.io/tutorials/mysql/remote-access

_OPTIONS_LIST="install_mysql 'Install the database server' \
               remote_access 'Enable remote access' \
               grant_privileges 'grant privileges to a database user'"

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get"
    _MYSQL_SERVICE="mysql"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
    _MYSQL_SERVICE="mysqld"
  fi

  _TITLE="--backtitle \"MySQL installation | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
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

mysql_as_root () {
  if [ "$1" = "." ]; then
    mysql -u root -e "$2" 2> /dev/null
  else
    mysql -u root -p$1 -e "$2" 2> /dev/null
  fi
}

install_mysql () {
  dialog --yesno "Confirm the installation of MySQL Server?" 0 0
  [ $? -eq 1 ] && main

  case $_OS_TYPE in
    deb)
      $_PACKAGE_COMMAND -y install mysql-server libmysqlclient-dev
      ;;
    rpm)
      $_PACKAGE_COMMAND -y install mysql-server mysql-devel

      service mysqld start
      ;;
  esac

  message "Notice" "MySQL successfully installed!"
}

remote_access () {
  dialog --yesno 'Do you want to enable remote access?' 0 0
  [ $? -eq 1 ] && main

  if [ $_OS_TYPE = "deb" ]; then
    change_file "replace" "/etc/mysql/my.cnf" "bind-address" "#bind-address"
  elif [ $_OS_TYPE = "rpm" ]; then
    change_file "append" "/etc/my.cnf" "symbolic-links=0" "bind-address = 0.0.0.0"
  fi

  service $_MYSQL_SERVICE restart

  message "Notice" "Enabling remote access successfully held!"
}

grant_privileges () {
  _MYSQL_ROOT_PASSWORD=$(input "Enter the password of the root user in MySQL")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_ROOT_PASSWORD" ] && _MYSQL_ROOT_PASSWORD="."

  _GRANT_DATABASE=$(input "Enter the database name")
  [ $? -eq 1 ] && main
  [ -z "$_GRANT_DATABASE" ] && message "Alert" "The database name can not be blank!"

  _GRANT_USER=$(input "Enter the user name")
  [ $? -eq 1 ] && main
  [ -z "$_GRANT_USER" ] && message "Alert" "The user name can not be blank!"

  _GRANT_PASSWORD=$(input "Enter the password")
  [ $? -eq 1 ] && main
  [ -z "$_GRANT_PASSWORD" ] && message "Alert" "The password can not be blank!"

  mysql_as_root $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON $_GRANT_DATABASE.* TO '$_GRANT_USER'@'%' IDENTIFIED BY '$_GRANT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

  message "Notice" "Grant privileges successfully held!"
}

main () {
  tool_check dialog

  _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_OPTION" ]; then
    clear && exit 0
  else
    $_OPTION
  fi
}

os_check
main
