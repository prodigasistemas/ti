#!/bin/bash
# http://docs.sonarqube.org/display/SONAR/Installing+the+Server
# http://sonar-pkg.sourceforge.net
# http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern

_URL_CENTRAL="http://prodigasistemas.github.io"
_PACKAGE_COMMAND_DEBIAN="apt-get --force-yes"
_PACKAGE_COMMAND_CENTOS="yum"
_PROPERTIES_FOLDER="/opt/sonar/conf"
_DEFAULT_HOST="http://localhost:9000"
_RUNNER_VERSION_DEFAULT="2.4"
_OPTIONS_LIST="install_sonar 'Install the Sonar Server' configure_database 'Configure sonar with MySQL Database' install_sonar_runner 'Install the Sonar Runner' configure_nginx 'configure host on NGINX'"

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
}

change_file () {
  _BACKUP=".backup-`date +"%Y%m%d%H%M%S%N"`"

  sed -i$_BACKUP -e 's|$2|$3|g' $1
}

run_as_root () {
  su -c "$1"
}

install_sonar () {
  _JAVA_PATH=$(input "Enter the path of java 8" "/opt/java-oracle-8/bin/java")
  [ $? = 1 ] && main

  if [ -z "$_JAVA_PATH" ]; then
    message "Alert" "The java 8 path can not be blank!"
    main
  fi

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
  main
}

configure_database () {
  if command -v mysql > /dev/null; then
    _SERVER_ADDRESS=$(input "Enter the address of the MySQL Server" "localhost")
    [ $? = 1 ] && main

    if [ -z "$_SERVER_ADDRESS" ]; then
      message "Alert" "The server address can not be blank!"
      main
    fi
  else
    message "Alert" "MySQL Client is not installed!"
    main
  fi

  _MYSQL_ROOT_PASSWORD=$(input "Enter the password of the root user in MySQL" "")
  [ $? = 1 ] && main

  if [ -z "$_MYSQL_ROOT_PASSWORD" ]; then
    message "Alert" "The password can not be blank!"
    main
  fi

  _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL" "")
  [ $? = 1 ] && main

  if [ -z "$_MYSQL_SONAR_PASSWORD" ]; then
    message "Alert" "The password can not be blank!"
    main
  fi

  mysql -h $_SERVER_ADDRESS -u root -p$_MYSQL_ROOT_PASSWORD -e "CREATE USER 'sonar'@'$_SERVER_ADDRESS' IDENTIFIED BY '$_MYSQL_SONAR_PASSWORD';"
  mysql -h $_SERVER_ADDRESS -u root -p$_MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON sonar.* TO 'sonar'@'$_SERVER_ADDRESS' WITH GRANT OPTION;"
  mysql -h $_SERVER_ADDRESS -u sonar -p$_MYSQL_SONAR_PASSWORD -e "CREATE DATABASE sonar;"

  change_file "$_PROPERTIES_FOLDER/sonar.properties" "^#sonar.jdbc.username=" "sonar.jdbc.username=sonar"
  change_file "$_PROPERTIES_FOLDER/sonar.properties" "^#sonar.jdbc.password=" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
  change_file "$_PROPERTIES_FOLDER/sonar.properties" "localhost:3306" "$_SERVER_ADDRESS:3306"
  change_file "$_PROPERTIES_FOLDER/sonar.properties" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

  service sonar restart

  message "Notice" "Connection to the database configured!"
  main
}

install_sonar_runner () {
  _RUNNER_VERSION=$(input "Enter the version of the Sonar Runner" "$_RUNNER_VERSION_DEFAULT")
  [ $? = 1 ] && main

  if [ -z "$_RUNNER_VERSION" ]; then
    message "Alert" "The Sonar Runner version can not be blank!"
    main
  fi

  _HOST_ADDRESS=$(input "Enter the address of the Sonar Server" "$_DEFAULT_HOST")
  [ $? = 1 ] && main

  if [ -z "$_HOST_ADDRESS" ]; then
    message "Alert" "The server address can not be blank!"
    main
  fi

  _USER_TOKEN=$(input "Enter the user token in sonar" "")
  [ $? = 1 ] && main

  if [ -z "$_USER_TOKEN" ]; then
    message "Alert" "The server address can not be blank!"
    main
  fi

  _RUNNER_ZIP_FILE="sonar-runner-dist-$_RUNNER_VERSION.zip"

  wget "http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/$_RUNNER_VERSION/$_RUNNER_ZIP_FILE"

  unzip $_RUNNER_ZIP_FILE
  rm $_RUNNER_ZIP_FILE

  mv "sonar-runner-$_RUNNER_VERSION" /opt/sonar-runner

  _PROPERTIES_FILE="/opt/sonar-runner/conf/sonar-runner.properties"

  change_file "$_PROPERTIES_FILE" "^#sonar.host.url=$_DEFAULT_HOST" "sonar.host.url=$_HOST_ADDRESS"
  change_file "$_PROPERTIES_FILE" "^#sonar.login=admin" "sonar.login=$_USER_TOKEN"

  message "Notice" "Sonar Runner successfully installed!"
  main
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input "Enter the domain of sonar" "sonar.company.gov")
    [ $? = 1 ] && main

    if [ -z "$_DOMAIN" ]; then
      message "Alert" "The domain can not be blank!"
      main
    fi

    _HOST=$(input "Enter the host of Sonar server" "$_DEFAULT_HOST")
    [ $? = 1 ] && main

    if [ -z "$_HOST" ]; then
      message "Alert" "The host can not be blank!"
      main
    fi

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
tool_check curl
tool_check wget
tool_check dialog
tool_check unzip
main
