#!/bin/bash
# http://docs.sonarqube.org/display/SONAR/Installing+the+Server
# http://sonar-pkg.sourceforge.net
# http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern
# http://stackoverflow.com/questions/2634590/bash-script-variable-inside-variable
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

export _APP_NAME="SonarQube"
_SONAR_FOLDER="/opt/sonar"
_PROPERTIES_FOLDER="$_SONAR_FOLDER/conf"
_NGINX_DEFAULT_HOST="localhost:9000"
_DEFAULT_HOST="http://$_NGINX_DEFAULT_HOST"
_SCANNER_VERSION_DEFAULT="2.6.1"

_SONAR_OTHER_DOWNLOAD_URL="http://sonar.ggas.com.br/download"
_SONAR_OTHER_FILE="sonarqube-5.0.tar.gz"

_SONAR_SOURCE_QUBE="From www.sonarqube.org"
_SONAR_SOURCE_OTHER="From other sources"
_SONAR_SOURCE_LIST="QUBE '$_SONAR_SOURCE_QUBE' OTHER '$_SONAR_SOURCE_OTHER'"

_OPTIONS_LIST="install_sonar 'Install the Sonar Server' \
               configure_database 'Configure connection to MySQL database' \
               install_sonar_scanner 'Install the Sonar Scanner' \
               configure_nginx 'Configure host on NGINX'"

_OPTIONS_DATABASE="create_sonar_database 'Create the user and sonar database' \
                   import_sonar_database 'Import sonar database from SQL file' \
                   configure_sonar_properties 'Configure the connection to the database'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="https://prodigasistemas.github.io/ti"

  ping -c 1 "$(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g; s|/ti||g;' | cut -d: -f1)" > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

mysql_host_input () {
  _MYSQL_HOST=$(input_field "[default]" "Enter the host of the MySQL Server" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_HOST" ] && message "Alert" "The host of the MySQL Server can not be blank!"
}

mysql_connection_input () {
  mysql_host_input

  _MYSQL_PORT=$(input_field "[default]" "Enter the port of the MySQL Server" "3306")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_PORT" ] && message "Alert" "The port of the MySQL Server can not be blank!"
}

mysql_user_password_input () {
  _MYSQL_SONAR_PASSWORD=$(input_field "sonar.mysql.user.password" "Enter the password of the sonar user in MySQL")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"
}

install_sonar_qube () {
  case "$_OS_TYPE" in
    deb)
      run_as_root "echo deb http://downloads.sourceforge.net/project/sonar-pkg/deb binary/ > /etc/apt/sources.list.d/sonar.list"
      $_PACKAGE_COMMAND update
      $_PACKAGE_COMMAND --force-yes -y install sonar
      ;;
    rpm)
      wget -O /etc/yum.repos.d/sonar.repo http://downloads.sourceforge.net/project/sonar-pkg/rpm/sonar.repo
      $_PACKAGE_COMMAND -y install sonar
      admin_service sonar register
      ;;
  esac
}

install_sonar_other () {
  _SONAR_OTHER_DOWNLOAD_URL=$(input_field "sonar.other.url" "Enter the sonar download url" "$_SONAR_OTHER_DOWNLOAD_URL")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_OTHER_DOWNLOAD_URL" ] && message "Alert" "The sonar download url can not be blank!"

  _SONAR_OTHER_FILE=$(input_field "sonar.other.file" "Enter the sonar file" "$_SONAR_OTHER_FILE")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_OTHER_FILE" ] && message "Alert" "The sonar file can not be blank!"

  confirm "File download URL: $_SONAR_OTHER_DOWNLOAD_URL/$_SONAR_OTHER_FILE. Confirm?"
  [ $? -eq 1 ] && main

  java_check 7

  _JAVA_HOME=$(get_java_home 7)

  wget "$_SONAR_OTHER_DOWNLOAD_URL/$_SONAR_OTHER_FILE"
  [ $? -ne 0 ] && message "Error" "Download of file $_SONAR_OTHER_DOWNLOAD_URL/$_SONAR_OTHER_FILE unrealized!"

  tar -xzf "$_SONAR_OTHER_FILE"
  rm "$_SONAR_OTHER_FILE"

  _DIR_EXTRACTED=${_SONAR_OTHER_FILE//.tar.gz/}
  mv "$_DIR_EXTRACTED" $_SONAR_FOLDER
  mv "$_PROPERTIES_FOLDER/sonar.properties_old" "$_PROPERTIES_FOLDER/sonar.properties"

  change_file "replace" "$_PROPERTIES_FOLDER/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_HOME/bin/java"

  ln -sf "$_SONAR_FOLDER/bin/linux-x86-$_OS_ARCH/sonar.sh" /etc/init.d/sonar

  admin_service sonar register

  admin_service sonar restart
}

install_sonar () {
  java_check 8

  _JAVA_HOME=$(get_java_home 8)

  _JAVA_COMMAND=$(input_field "[default]" "Enter the path of command Java 8" "$_JAVA_HOME/bin/java")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_COMMAND" ] && message "Alert" "The Java command can not be blank!"

  admin_service sonar stop 2> /dev/null

  backup_folder $_SONAR_FOLDER

  _SONAR_OPTION_LOWERCASE=$(echo "$_SONAR_OPTION" | tr '[:upper:]' '[:lower:]')

  install_sonar_"$_SONAR_OPTION_LOWERCASE"

  change_file "replace" "$_PROPERTIES_FOLDER/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_COMMAND"

  if [ "$_SONAR_OPTION" = "QUBE" ] && [ "$_OS_TYPE" = "rpm" ]; then
    admin_service sonar restart 2> /dev/null
  fi

  [ $? -eq 0 ] && message "Notice" "Sonar successfully installed!"
}

create_sonar_database () {
  if command -v mysql > /dev/null; then
    mysql_host_input
  else
    message "Alert" "MySQL Client is not installed!"
  fi

  _MYSQL_ROOT_PASSWORD=$(input_field "sonar.mysql.root.password" "Enter the password of the root user in MySQL")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_ROOT_PASSWORD" ] && message "Alert" "The root password can not be blank!"

  mysql_user_password_input

  mysql_as_root "$_MYSQL_ROOT_PASSWORD" "DROP DATABASE IF EXISTS sonar;"
  mysql_as_root "$_MYSQL_ROOT_PASSWORD" "CREATE DATABASE sonar;"
  mysql_as_root "$_MYSQL_ROOT_PASSWORD" "CREATE USER sonar@$_MYSQL_HOST IDENTIFIED BY '$_MYSQL_SONAR_PASSWORD';"
  mysql_as_root "$_MYSQL_ROOT_PASSWORD" "GRANT ALL PRIVILEGES ON sonar.* TO sonar@$_MYSQL_HOST WITH GRANT OPTION;"
  mysql_as_root "$_MYSQL_ROOT_PASSWORD" "FLUSH PRIVILEGES;"

  [ $? -eq 0 ] && message "Notice" "User and database sonar successfully created!"
}

import_sonar_database () {
  mysql_connection_input

  mysql_user_password_input

  _SONAR_OTHER_DOWNLOAD_URL=$(input_field "sonar.mysql.import.database.url" "Enter the sonar download URL" "$_SONAR_OTHER_DOWNLOAD_URL")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_OTHER_DOWNLOAD_URL" ] && message "Alert" "The sonar download URL can not be blank!"

  _SONAR_OTHER_SQL_FILE=$(input_field "sonar.mysql.import.database.file" "Enter the sonar SQL file to import" "sonar.sql")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_OTHER_SQL_FILE" ] && message "Alert" "The sonar SQL file can not be blank!"

  confirm "SQL file download URL: $_SONAR_OTHER_DOWNLOAD_URL/$_SONAR_OTHER_SQL_FILE. Confirm?"
  [ $? -eq 1 ] && main

  _DIR_SQL_TEMP="/tmp/sonar-sql-download"
  delete_file $_DIR_SQL_TEMP
  mkdir -p $_DIR_SQL_TEMP

  cd $_DIR_SQL_TEMP && wget -c "$_SONAR_OTHER_DOWNLOAD_URL/$_SONAR_OTHER_SQL_FILE"
  [ $? -ne 0 ] && message "Error" "Download of file $_SONAR_OTHER_DOWNLOAD_URL/$_SONAR_OTHER_SQL_FILE unrealized!"

  _CHECKS_FILE_ZIPPED=$(file -b "$_DIR_SQL_TEMP/$_SONAR_OTHER_SQL_FILE" | grep '[Z,z]ip')
  if [ -n "$_CHECKS_FILE_ZIPPED" ]; then
    cd $_DIR_SQL_TEMP && unzip "$_SONAR_OTHER_SQL_FILE"
    rm "$_DIR_SQL_TEMP/$_SONAR_OTHER_SQL_FILE"
    _SONAR_OTHER_SQL_FILE=$(ls $_DIR_SQL_TEMP/*.sql)
  else
    _SONAR_OTHER_SQL_FILE=$_DIR_SQL_TEMP/$_SONAR_OTHER_SQL_FILE
  fi

  [ ! -e "$_SONAR_OTHER_SQL_FILE" ] && message "Alert" "$_SONAR_OTHER_SQL_FILE file was not found. Import unrealized!"

  import_database "mysql" "$_MYSQL_HOST" "$_MYSQL_PORT" "sonar" "sonar" "$_MYSQL_SONAR_PASSWORD" "$_SONAR_OTHER_SQL_FILE"

  delete_file "$_SONAR_OTHER_SQL_FILE"

  [ $? -eq 0 ] && message "Notice" "Sonar database successfully imported!"
}

configure_sonar_properties () {
  _PROPERTIES_FILE="$_PROPERTIES_FOLDER/sonar.properties"

  [ ! -e "$_PROPERTIES_FILE" ] && message "Alert" "The properties file '$_PROPERTIES_FILE' was not found!"

  mysql_connection_input

  mysql_user_password_input

  _PROPERTIES_USERNAME=$(grep sonar.jdbc.username $_PROPERTIES_FILE)
  _PROPERTIES_PASSWORD=$(grep sonar.jdbc.username $_PROPERTIES_FILE)

  change_file "replace" "$_PROPERTIES_FILE" "^$_PROPERTIES_USERNAME" "sonar.jdbc.username=sonar"
  change_file "replace" "$_PROPERTIES_FILE" "^$_PROPERTIES_PASSWORD" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
  change_file "replace" "$_PROPERTIES_FILE" "localhost:3306" "$_MYSQL_HOST:$_MYSQL_PORT"
  change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

  admin_service sonar restart

  [ $? -eq 0 ] && message "Notice" "Connection to the database configured!"
}

configure_database () {
  _OPTION=$(menu "Select which configuration" "$_OPTIONS_DATABASE")
  [ -z "$_OPTION" ] && main

  $_OPTION
}

install_sonar_scanner () {
  _SCANNER_VERSION=$(input_field "sonar.scanner.version" "Enter the version of the Sonar Scanner" "$_SCANNER_VERSION_DEFAULT")
  [ $? -eq 1 ] && main
  [ -z "$_SCANNER_VERSION" ] && message "Alert" "The Sonar Scanner version can not be blank!"

  _HOST_ADDRESS=$(input_field "sonar.scanner.host" "Enter the address of the Sonar Server" "$_DEFAULT_HOST")
  [ $? -eq 1 ] && main
  [ -z "$_HOST_ADDRESS" ] && message "Alert" "The server address can not be blank!"

  if [ "$_SONAR_OPTION" = "QUBE" ]; then
    _USER_TOKEN=$(input "Enter the user token in sonar")
    [ $? -eq 1 ] && main
    [ -z "$_USER_TOKEN" ] && message "Alert" "The user token can not be blank!"

  elif [ "$_SONAR_OPTION" = "OTHER" ]; then
    mysql_connection_input

    mysql_user_password_input

  fi

  _SCANNER_ZIP_FILE="sonar-scanner-$_SCANNER_VERSION.zip"

  wget "https://sonarsource.bintray.com/Distribution/sonar-scanner-cli/$_SCANNER_ZIP_FILE"

  unzip -oq "$_SCANNER_ZIP_FILE"
  rm "$_SCANNER_ZIP_FILE"

  mv "sonar-scanner-$_SCANNER_VERSION" /opt/
  ln -sf "/opt/sonar-scanner-$_SCANNER_VERSION" /opt/sonar-scanner

  _PROPERTIES_FILE="/opt/sonar-scanner/conf/sonar-scanner.properties"

  change_file "replace" "$_PROPERTIES_FILE" "^#sonar.host.url=$_DEFAULT_HOST" "sonar.host.url=$_HOST_ADDRESS"

  if [ "$_SONAR_OPTION" = "QUBE" ]; then
    echo "sonar.login=$_USER_TOKEN" >> $_PROPERTIES_FILE

  elif [ "$_SONAR_OPTION" = "OTHER" ]; then
    _PROPERTIES_USERNAME=$(grep sonar.jdbc.username $_PROPERTIES_FILE)
    _PROPERTIES_PASSWORD=$(grep sonar.jdbc.username $_PROPERTIES_FILE)

    change_file "replace" "$_PROPERTIES_FILE" "^$_PROPERTIES_USERNAME" "sonar.jdbc.username=sonar"
    change_file "replace" "$_PROPERTIES_FILE" "^$_PROPERTIES_PASSWORD" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
    change_file "replace" "$_PROPERTIES_FILE" "localhost:3306" "$_MYSQL_HOST:$_MYSQL_PORT"
    change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

  fi

  [ $? -eq 0 ] && message "Notice" "Sonar Scanner successfully installed!"
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "sonar.nginx.domain" "Enter the domain of Sonar" "sonar.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input_field "sonar.nginx.host" "Enter the host of Sonar server" "$_NGINX_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > sonar.conf

    change_file "replace" "sonar.conf" "APP" "sonar"
    change_file "replace" "sonar.conf" "DOMAIN" "$_DOMAIN"
    change_file "replace" "sonar.conf" "HOST" "$_HOST"

    mv sonar.conf /etc/nginx/conf.d/
    rm sonar.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed!"
  fi
}

main () {
  _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_MAIN_OPTION" ]; then
    type_menu
  else
    $_MAIN_OPTION
  fi
}

type_menu () {
  os_check
  tool_check curl
  tool_check wget
  tool_check unzip

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _SONAR_OPTION=$(menu "Select the sonar source" "$_SONAR_SOURCE_LIST")

    if [ -z "$_SONAR_OPTION" ]; then
      clear && exit 0
    else
      _TEXT="_SONAR_SOURCE_$_SONAR_OPTION"
      _TEXT=$(echo "${!_TEXT}")
      export _TITLE="--backtitle \"Tools Installer - $_APP_NAME - $_TEXT | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""

      main
    fi
  else
    _SONAR_OPTION="$(search_value sonar.source | tr '[:lower:]' '[:upper:]')"

    case "$_SONAR_OPTION" in
      QUBE|OTHER)
        install_sonar

        if [ -n "$(search_app sonar.mysql)" ]; then
          create_sonar_database
          configure_sonar_properties

          [ -n "$(search_app sonar.mysql.import.database)" ] && import_sonar_database
        fi

        [ -n "$(search_app sonar.scanner)" ] && install_sonar_scanner
        [ -n "$(search_app sonar.nginx)" ] && configure_nginx
        ;;
    esac
  fi
}

setup
type_menu
