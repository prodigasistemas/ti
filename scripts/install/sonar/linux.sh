#!/bin/bash
# http://sonar-pkg.sourceforge.net/

_PACKAGE_COMMAND_DEBIAN="apt-get --force-yes"
_PACKAGE_COMMAND_CENTOS="yum"
_OPTIONS_LIST="install_sonar 'Install the Sonar Server' configure_database 'Configure sonar with MySQL Database'"

os_check () {
  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -is | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_DEBIAN
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_CENTOS
  fi

  _TITLE="--backtitle \"Sonar installation - OS: $_OS_NAME\""
}

wget_check () {
  echo "Checking for wget..."
  if command -v wget > /dev/null; then
    echo "Detected wget..."
  else
    echo "Installing wget..."
    $_PACKAGE_COMMAND install -y wget
  fi
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

run_as_root () {
  su -c "$1"
}

install_sonar () {
  dialog --yesno "Confirm the installation of Sonar in $_OS_NAME?" 0 0
  [ $? = 1 ] && clear && exit 0

  if [ $_OS_TYPE = "deb" ]; then
    run_as_root "echo deb http://downloads.sourceforge.net/project/sonar-pkg/deb binary/ > /etc/apt/sources.list.d/sonar.list"

    $_PACKAGE_COMMAND update
  elif [ $_OS_TYPE = "rpm" ]; then
    wget -O /etc/yum.repos.d/sonar.repo http://downloads.sourceforge.net/project/sonar-pkg/rpm/sonar.repo
  fi

  $_PACKAGE_COMMAND -y install sonar

  change_file "/opt/sonar/conf/wrapper.conf" "wrapper.java.command=java" "wrapper.java.command=/usr/lib/jvm/java-oracle-8/bin/java"

  [ $_OS_TYPE = "rpm" ] && service sonar start

  message "Notice" "Sonar successfully installed!"
  clear
}

configure_database () {
  _MYSQL_ROOT_PASSWORD=$(input "Enter the root password MySQL" "")
  [ $? = 1 ] && main

  if [ -z "$_MYSQL_ROOT_PASSWORD" ]; then
    message "Alert" "The password can not be blank!"
    main
  fi

  _MYSQL_SONAR_PASSWORD=$(input "Enter the sonar password MySQL" "")
  [ $? = 1 ] && main

  if [ -z "$_MYSQL_SONAR_PASSWORD" ]; then
    message "Alert" "The password can not be blank!"
    main
  fi

  _SERVER_ADDRESS=$(input "Enter the address of the MySQL Server " "localhost")
  [ $? = 1 ] && main

  if [ -z "$_SERVER_ADDRESS" ]; then
    message "Alert" "The server address can not be blank!"
    main
  fi

  mysql -u root -p$_MYSQL_ROOT_PASSWORD -e "CREATE USER 'sonar'@'$_SERVER_ADDRESS' IDENTIFIED BY '$_MYSQL_SONAR_PASSWORD';"
  mysql -u root -p$_MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON sonar.* TO 'sonar'@'$_SERVER_ADDRESS' WITH GRANT OPTION;"
  mysql -u sonar -p$_MYSQL_SONAR_PASSWORD -e "CREATE DATABASE sonar;"

  _PROPERTIES_FOLDER="/opt/sonar/conf"

  change_file "$_PROPERTIES_FOLDER/sonar.properties" "#sonar.jdbc.username=" "sonar.jdbc.username=sonar"
  change_file "$_PROPERTIES_FOLDER/sonar.properties" "#sonar.jdbc.password=" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
  change_file "$_PROPERTIES_FOLDER/sonar.properties" "localhost:3306" "$_SERVER_ADDRESS:3306"

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
wget_check
dialog_check
main
