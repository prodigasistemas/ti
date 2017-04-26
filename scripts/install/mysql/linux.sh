#!/bin/bash
# https://easyengine.io/tutorials/mysql/remote-access
# http://stackoverflow.com/questions/7739645/install-mysql-on-ubuntu-without-password-prompt

_APP_NAME="MySQL"
_OPTIONS_LIST="install_mysql_server 'Install the database server' \
               install_mysql_client 'Install the database client' \
               create_database 'Create database' \
               add_user 'Add user to Database' \
               change_password 'Change password the user' \
               remote_access 'Enable remote access'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="https://prodigasistemas.github.io"

  ping -c 1 $(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g' | cut -d: -f1) > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

mysql_root_password_input () {
  _MYSQL_ROOT_PASSWORD=$(input_field "[default]" "Enter the password of the root user in $_MYSQL_NAME")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_ROOT_PASSWORD" ] && message "Alert" "The root password can not be blank!"
}

mysql_database_name_input () {
  _MYSQL_DATABASE=$(input_field "[default]" "Enter the database name")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_DATABASE" ] && message "Alert" "The database name can not be blank!"
}

mysql_user_input () {
  _MYSQL_HOST=$(input_field "[default]" "Enter the host name" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_HOST" ] && message "Alert" "The host name can not be blank!"

  _MYSQL_USER_NAME=$(input_field "[default]" "Enter the user name")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_USER_NAME" ] && message "Alert" "The user name can not be blank!"

  _MYSQL_USER_PASSWORD=$(input_field "[default]" "Enter the user password")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_USER_PASSWORD" ] && message "Alert" "The user password can not be blank!"
}

install_mysql_server () {
  confirm "Confirm the installation of $_MYSQL_NAME Server?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
      debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

      $_PACKAGE_COMMAND -y install mysql-server libmysqlclient-dev
      ;;
    rpm)
      $_PACKAGE_COMMAND -y install $_MYSQL_NAME_LOWERCASE-server $_MYSQL_NAME_LOWERCASE-devel

      admin_service $_MYSQL_SERVICE register

      admin_service $_MYSQL_SERVICE start

      mysqladmin -u root password 'root'
      ;;
  esac

  [ $? -eq 0 ] && message "Notice" "$_MYSQL_NAME Server successfully installed! The root password is root"
}

install_mysql_client () {
  confirm "Confirm the installation of $_MYSQL_NAME Client?"
  [ $? -eq 1 ] && main

  [ "$_OS_TYPE" = "deb" ] && _PACKAGE="mysql-client"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGE=$_MYSQL_NAME_LOWERCASE

  $_PACKAGE_COMMAND -y install $_PACKAGE

  [ $? -eq 0 ] && message "Notice" "MySQL Client successfully installed!"
}

create_database () {
  mysql_database_name_input

  mysql_root_password_input

  confirm "Confirm create database $_MYSQL_DATABASE?"
  [ $? -eq 1 ] && main

  mysql_as_root $_MYSQL_ROOT_PASSWORD "CREATE DATABASE $_MYSQL_DATABASE;"

  [ $? -eq 0 ] && message "Notice" "Database $_MYSQL_DATABASE created successfully!"
}

add_user () {
  mysql_root_password_input

  mysql_database_name_input

  mysql_user_input

  confirm "Confirm create user $_MYSQL_USER_NAME@$_MYSQL_HOST to database $_MYSQL_DATABASE?"
  [ $? -eq 1 ] && main

  mysql_as_root $_MYSQL_ROOT_PASSWORD "CREATE USER '$_MYSQL_USER_NAME'@'$_MYSQL_HOST' IDENTIFIED BY '$_MYSQL_USER_PASSWORD';"
  mysql_as_root $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON $_MYSQL_DATABASE.* TO '$_MYSQL_USER_NAME'@'$_MYSQL_HOST' WITH GRANT OPTION;"
  mysql_as_root $_MYSQL_ROOT_PASSWORD "FLUSH PRIVILEGES;"

  [ $? -eq 0 ] && message "Notice" "User $_MYSQL_USER_NAME added and granted successfully!"
}

change_password () {
  mysql_root_password_input

  mysql_user_input

  confirm "Confirm change $_MYSQL_USER_NAME@$_MYSQL_HOST password?"
  [ $? -eq 1 ] && main

  mysql_as_root $_MYSQL_ROOT_PASSWORD "SET PASSWORD FOR '$_MYSQL_USER_NAME'@'$_MYSQL_HOST' = PASSWORD('$_MYSQL_USER_PASSWORD');"

  [ $? -eq 0 ] && message "Notice" "Password changed successfully!"
}

remote_access () {
  confirm "Do you want to enable remote access?"
  [ $? -eq 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    change_file "replace" "/etc/mysql/my.cnf" "bind-address" "#bind-address"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    change_file "append" "/etc/my.cnf" "symbolic-links=0" "bind-address = 0.0.0.0"
  fi

  admin_service $_MYSQL_SERVICE restart

  [ $? -eq 0 ] && message "Notice" "Enabling remote access successfully held!"
}

main () {
  _MYSQL_NAME="MySQL"
  _MYSQL_SERVICE="mysql"

  if [ "$_OS_TYPE" = "rpm" ]; then
    if [ "$_OS_RELEASE" -le 6 ]; then
      _MYSQL_SERVICE="mysqld"
    else
      _MYSQL_NAME="MariaDB"
      _MYSQL_SERVICE="mariadb"
    fi
  fi

  _MYSQL_NAME_LOWERCASE=$(echo $_MYSQL_NAME | tr [:upper:] [:lower:])

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app mysql.client)" ] && install_mysql_client
    [ -n "$(search_app mysql.server)" ] && install_mysql_server
    [ "$(search_value mysql.server.remote.access)" = "yes" ] && remote_access
  fi
}

setup
main
