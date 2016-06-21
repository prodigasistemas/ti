#!/bin/bash
# https://easyengine.io/tutorials/mysql/remote-access
# http://stackoverflow.com/questions/7739645/install-mysql-on-ubuntu-without-password-prompt

_APP_NAME="MySQL"
_OPTIONS_LIST="install_mysql_server 'Install the database server' \
               install_mysql_client 'Install the database client' \
               remote_access 'Enable remote access' \
               grant_privileges 'grant privileges to a database user'"

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

install_mysql_server () {
  confirm "Confirm the installation of MySQL Server?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      _PASSWORD_MESSAGE=" The root password is root"
      debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
      debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

      $_PACKAGE_COMMAND -y install mysql-server libmysqlclient-dev
      ;;
    rpm)
      _PASSWORD_MESSAGE=" The root user has no password"
      $_PACKAGE_COMMAND -y install mysql-server mysql-devel

      register_service mysqld

      service mysqld start
      ;;
  esac

  [ $? -eq 0 ] && message "Notice" "MySQL Server successfully installed!${_PASSWORD_MESSAGE}"
}

install_mysql_client () {
  confirm "Confirm the installation of MySQL Client?"
  [ $? -eq 1 ] && main

  [ "$_OS_TYPE" = "deb" ] && _PACKAGE="mysql-client"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGE="mysql"

  $_PACKAGE_COMMAND -y install $_PACKAGE

  [ $? -eq 0 ] && message "Notice" "MySQL Client successfully installed!"
}

remote_access () {
  confirm "Do you want to enable remote access?"
  [ $? -eq 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    _MYSQL_SERVICE="mysql"
    change_file "replace" "/etc/mysql/my.cnf" "bind-address" "#bind-address"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _MYSQL_SERVICE="mysqld"
    change_file "append" "/etc/my.cnf" "symbolic-links=0" "bind-address = 0.0.0.0"
  fi

  service $_MYSQL_SERVICE restart

  [ $? -eq 0 ] && message "Notice" "Enabling remote access successfully held!"
}

grant_privileges () {
  _MYSQL_HOST=$(input_field "mysql.server.grant.privileges.host" "Enter the host of the MySQL Server" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_HOST" ] && message "Alert" "The host can not be blank!"

  _MYSQL_PORT=$(input_field "mysql.server.grant.privileges.port" "Enter the port of the MySQL Server" "3306")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_PORT" ] && message "Alert" "The port of the MySQL Server can not be blank!"

  _MYSQL_ROOT_PASSWORD=$(input_field "mysql.server.grant.privileges.root.password" "Enter the password of the root user in MySQL")
  [ $? -eq 1 ] && main
  if [ -z "$_MYSQL_ROOT_PASSWORD" ]; then
    if [ "$_OS_TYPE" = "rpm" ]; then
      _MYSQL_ROOT_PASSWORD="[no_password]"
    else
       message "Alert" "The root password can not be blank!"
    fi
  fi

  _GRANT_DATABASE=$(input_field "mysql.server.grant.privileges.database" "Enter the database name")
  [ $? -eq 1 ] && main
  [ -z "$_GRANT_DATABASE" ] && message "Alert" "The database name can not be blank!"

  _GRANT_USER=$(input_field "mysql.server.grant.privileges.user.name" "Enter the user name")
  [ $? -eq 1 ] && main
  [ -z "$_GRANT_USER" ] && message "Alert" "The user name can not be blank!"

  _GRANT_PASSWORD=$(input_field "mysql.server.grant.privileges.user.password" "Enter the user password")
  [ $? -eq 1 ] && main
  [ -z "$_GRANT_PASSWORD" ] && message "Alert" "The user password can not be blank!"

  mysql_as_root $_MYSQL_HOST $_MYSQL_PORT $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON $_GRANT_DATABASE.* TO '$_GRANT_USER'@'%' IDENTIFIED BY '$_GRANT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

  [ $? -eq 0 ] && message "Notice" "Grant privileges successfully held!"
}

main () {
  tool_check dialog

  if [ "$(provisioning)" = "manual" ]; then
    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ ! -z "$(search_app mysql.client)" ] && install_mysql_client
    [ ! -z "$(search_app mysql.server)" ] && install_mysql_server
    [ "$(search_value mysql.server.remote_access)" = "yes" ] && remote_access
    [ ! -z "$(search_app mysql.server.grant.privileges)" ] && grant_privileges
  fi
}

setup
main
