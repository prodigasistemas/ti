#!/bin/bash
# http://docs.sonarqube.org/display/SONAR/Installing+the+Server
# http://sonar-pkg.sourceforge.net
# http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern

_URL_CENTRAL="http://prodigasistemas.github.io"
_PACKAGE_COMMAND_DEBIAN="apt-get --force-yes"
_PACKAGE_COMMAND_CENTOS="yum"
_PROPERTIES_FOLDER="/opt/sonar/conf"
_DEFAULT_HOST="http://localhost:9000"
_CONNECTION_ADDRESS_MYSQL="localhost:3306"
_RUNNER_VERSION_DEFAULT="2.4"
_OPTIONS_LIST="install_sonar 'Install the Sonar Server' configure_database 'Configure connection to MySQL database' install_sonar_runner 'Install the Sonar Runner' configure_nginx 'configure host on NGINX'"

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
  _BACKUP=".backup-`date +"%Y%m%d%H%M%S%N"`"

  sed -i$_BACKUP -e 's|$2|$3|g' $1
}

run_as_root () {
  su -c "$1"
}

mysql_as_root () {
  mysql -h $1 -u root -p$2 -e "$3" 2> /dev/null
}

install_sonar () {
  _JAVA_PATH=$(input "Enter the path of Java 8" "/opt/java-oracle-8/bin/java")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_PATH" ] && message "Alert" "The Java 8 path can not be blank!"

  if [ $_OS_TYPE = "deb" ]; then
    run_as_root "echo deb http://downloads.sourceforge.net/project/sonar-pkg/deb binary/ > /etc/apt/sources.list.d/sonar.list"

    $_PACKAGE_COMMAND update
  elif [ $_OS_TYPE = "rpm" ]; then
    wget -O /etc/yum.repos.d/sonar.repo http://downloads.sourceforge.net/project/sonar-pkg/rpm/sonar.repo
  fi

  $_PACKAGE_COMMAND -y install sonar

  change_file "$_PROPERTIES_FOLDER/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_PATH"

  [ $_OS_TYPE = "rpm" ] && service sonar start

  message "Notice" "Sonar successfully installed!"
}

configure_database () {
  _OPTION=$(menu "Select which configuration" " database 'Create the user and sonar database' sonar.properties 'Configure the connection to the database'")
  [ -z "$_OPTION" ] && main

  if [ "$_OPTION" = "database" ]; then
    if command -v mysql > /dev/null; then
      _SERVER_ADDRESS=$(input "Enter the address and port of the MySQL Server" "$_CONNECTION_ADDRESS_MYSQL")
      [ $? -eq 1 ] && main
      [ -z "$_SERVER_ADDRESS" ] && message "Alert" "The server address can not be blank!"

      _HOST_CONNECTION=$(echo $_SERVER_ADDRESS | cut -d: -f1)
    else
      message "Alert" "MySQL Client is not installed!"
    fi

    _MYSQL_ROOT_PASSWORD=$(input "Enter the password of the root user in MySQL")
    [ $? -eq 1 ] && main
    [ -z "$_MYSQL_ROOT_PASSWORD" ] && message "Alert" "The root password can not be blank!"

    _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
    [ $? -eq 1 ] && main
    [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

    mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "CREATE DATABASE IF NOT EXISTS sonar;"
    mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "CREATE USER sonar@$_HOST_CONNECTION IDENTIFIED BY '$_MYSQL_SONAR_PASSWORD';"
    mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON sonar.* TO sonar@$_HOST_CONNECTION WITH GRANT OPTION; FLUSH PRIVILEGES;"

    message "Notice" "User and database sonar successfully created!"

  elif [ "$_OPTION" = "sonar.properties" ]; then
    _PROPERTIES_FILE="$_PROPERTIES_FOLDER/sonar.properties"

    [ ! -e "$_PROPERTIES_FILE" ] && message "Alert" "The properties file '$_PROPERTIES_FILE' was not found!"

    _SERVER_ADDRESS=$(input "Enter the address and port of the MySQL Server" "$_CONNECTION_ADDRESS_MYSQL")
    [ $? -eq 1 ] && main
    [ -z "$_SERVER_ADDRESS" ] && message "Alert" "The server address can not be blank!"

    _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
    [ $? -eq 1 ] && main
    [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

    change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.username=" "sonar.jdbc.username=sonar"
    change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.password=" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
    change_file "$_PROPERTIES_FILE" "$_CONNECTION_ADDRESS_MYSQL" "$_SERVER_ADDRESS"
    change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

    service sonar restart

    message "Notice" "Connection to the database configured!"
  fi
}

install_sonar_runner () {
  _RUNNER_VERSION=$(input "Enter the version of the Sonar Runner" "$_RUNNER_VERSION_DEFAULT")
  [ $? -eq 1 ] && main
  [ -z "$_RUNNER_VERSION" ] && message "Alert" "The Sonar Runner version can not be blank!"

  _HOST_ADDRESS=$(input "Enter the address of the Sonar Server" "$_DEFAULT_HOST")
  [ $? -eq 1 ] && main
  [ -z "$_HOST_ADDRESS" ] && message "Alert" "The server address can not be blank!"

  _USER_TOKEN=$(input "Enter the user token in sonar")
  [ $? -eq 1 ] && main
  [ -z "$_USER_TOKEN" ] && message "Alert" "The user token can not be blank!"

  _RUNNER_ZIP_FILE="sonar-runner-dist-$_RUNNER_VERSION.zip"

  wget "http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/$_RUNNER_VERSION/$_RUNNER_ZIP_FILE"

  unzip $_RUNNER_ZIP_FILE
  rm $_RUNNER_ZIP_FILE

  mv "sonar-runner-$_RUNNER_VERSION" /opt/sonar-runner

  _PROPERTIES_FILE="/opt/sonar-runner/conf/sonar-runner.properties"

  change_file "$_PROPERTIES_FILE" "^#sonar.host.url=$_DEFAULT_HOST" "sonar.host.url=$_HOST_ADDRESS"
  change_file "$_PROPERTIES_FILE" "^#sonar.login=admin" "sonar.login=$_USER_TOKEN"

  message "Notice" "Sonar Runner successfully installed!"
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input "Enter the domain of sonar" "sonar.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input "Enter the host of Sonar server" "$_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_URL_CENTRAL/scripts/templates/nginx/app.redirect.conf" > sonar.conf

    change_file "sonar.conf" "APP" "sonar"
    change_file "sonar.conf" "DOMAIN" "$_DOMAIN"
    change_file "sonar.conf" "HOST" "$_HOST"

    mv sonar.conf /etc/nginx/conf.d/
    rm sonar.conf*

    service nginx restart

    message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed!"
  fi
}

main () {
  tool_check curl
  tool_check wget
  tool_check dialog
  tool_check unzip

  _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_MAIN_OPTION" ]; then
    clear
    exit 0
  else
    $_MAIN_OPTION
  fi
}

os_check
main
