#!/bin/bash
# http://docs.sonarqube.org/display/SONAR/Installing+the+Server
# http://sonar-pkg.sourceforge.net
# http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern
# http://stackoverflow.com/questions/2634590/bash-script-variable-inside-variable
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

_APP_NAME="SonarQube"
_SONAR_FOLDER="/opt/sonar"
_PROPERTIES_FOLDER="$_SONAR_FOLDER/conf"
_NGINX_DEFAULT_HOST="localhost:9000"
_DEFAULT_HOST="http://$_NGINX_DEFAULT_HOST"
_CONNECTION_ADDRESS_MYSQL="localhost:3306"
_SCANNER_VERSION_DEFAULT="2.6.1"

_SONAR_GGAS_VERSION="5.0"
_SONAR_GGAS_DOWNLOAD_URL="http://sonar.ggas.com.br/download"
_SONAR_GGAS_FILE="sonarqube-$_SONAR_GGAS_VERSION.tar.gz"

_SONAR_SOURCE_QUBE="From www.sonarqube.org"
_SONAR_SOURCE_OTHER="From other sources"
_SONAR_SOURCE_LIST="QUBE '$_SONAR_SOURCE_QUBE' OTHER '$_SONAR_SOURCE_OTHER'"

_OPTIONS_LIST="install_sonar 'Install the Sonar Server' \
               configure_database 'Configure connection to MySQL database' \
               install_sonar_scanner 'Install the Sonar Scanner' \
               configure_nginx 'Configure host on NGINX'"

_OPTIONS_DATABASE="database 'Create the user and sonar database' \
                   sonar.properties 'Configure the connection to the database'"

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
      register_service sonar
      ;;
  esac
}

install_sonar_other () {
  _SONAR_GGAS_VERSION=$(input "Enter the sonar version" "$_SONAR_GGAS_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_GGAS_VERSION" ] && message "Alert" "The sonar version can not be blank!"

  _SONAR_GGAS_DOWNLOAD_URL=$(input "Enter the sonar download url" "$_SONAR_GGAS_DOWNLOAD_URL")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_GGAS_DOWNLOAD_URL" ] && message "Alert" "The sonar download url can not be blank!"

  _SONAR_GGAS_FILE="sonarqube-$_SONAR_GGAS_VERSION.tar.gz"

  _SONAR_GGAS_FILE=$(input "Enter the sonar download url" "$_SONAR_GGAS_FILE")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_GGAS_FILE" ] && message "Alert" "The sonar file can not be blank!"

  confirm "File download URL: $_SONAR_GGAS_DOWNLOAD_URL/$_SONAR_GGAS_FILE. Confirm?"
  [ $? -eq 1 ] && main

  wget "$_SONAR_GGAS_DOWNLOAD_URL/$_SONAR_GGAS_FILE"
  tar -xvzf "$_SONAR_GGAS_FILE"
  rm "$_SONAR_GGAS_FILE"

  mv "sonarqube-$_SONAR_GGAS_VERSION" $_SONAR_FOLDER
  mv "$_SONAR_FOLDER/conf/sonar.properties_old" "$_SONAR_FOLDER/conf/sonar.properties"

  ln -sf "$_SONAR_FOLDER/bin/linux-x86-$_OS_ARCH/sonar.sh" /etc/init.d/sonar

  register_service sonar

  service sonar restart
}

install_sonar () {
  _JAVA_PATH=$(input "Enter the path of command java 8" "java")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_PATH" ] && message "Alert" "The command can not be blank!"

  service sonar stop

  backup_folder $_SONAR_FOLDER

  case $_SONAR_OPTION in
    QUBE)
      install_sonar_qube
      ;;
    OTHER)
      install_sonar_other
      ;;
  esac

  change_file "replace" "$_PROPERTIES_FOLDER/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_PATH"

  if [ "$_SONAR_OPTION" = "QUBE" ] && [ "$_OS_TYPE" = "rpm" ]; then
    service sonar restart
  fi

  message "Notice" "Sonar successfully installed!"
}

configure_database () {
  _OPTION=$(menu "Select which configuration" "$_OPTIONS_DATABASE")
  [ -z "$_OPTION" ] && main

  case $_OPTION in
    database)
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
      if [ -z "$_MYSQL_ROOT_PASSWORD" ]; then
        if [ "$_OS_TYPE" = "rpm" ]; then
          _MYSQL_ROOT_PASSWORD="[no_password]"
        else
           message "Alert" "The root password can not be blank!"
        fi
      fi

      _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
      [ $? -eq 1 ] && main
      [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

      mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "CREATE DATABASE IF NOT EXISTS sonar;"
      mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "CREATE USER sonar@$_HOST_CONNECTION IDENTIFIED BY '$_MYSQL_SONAR_PASSWORD';"
      mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON sonar.* TO sonar@$_HOST_CONNECTION WITH GRANT OPTION; FLUSH PRIVILEGES;"

      if [ "$_SONAR_OPTION" = "OTHER" ]; then
        _SONAR_GGAS_DOWNLOAD_URL=$(input "Enter the sonar download URL" "$_SONAR_GGAS_DOWNLOAD_URL")
        [ $? -eq 1 ] && main
        [ -z "$_SONAR_GGAS_DOWNLOAD_URL" ] && message "Alert" "The sonar download URL can not be blank!"

        _SONAR_GGAS_SQL_FILE=$(input "Enter the sonar SQL file to import" "sonar.sql")
        [ $? -eq 1 ] && main
        [ -z "$_SONAR_GGAS_SQL_FILE" ] && message "Alert" "The sonar SQL file can not be blank!"

        confirm "SQL file download URL: $_SONAR_GGAS_DOWNLOAD_URL/$_SONAR_GGAS_SQL_FILE. Confirm?"
        [ $? -eq 1 ] && main

        wget $_SONAR_GGAS_DOWNLOAD_URL/$_SONAR_GGAS_SQL_FILE

        if [ -e "$_SONAR_GGAS_SQL_FILE" ]; then
          mysql -h $_HOST_CONNECTION -u sonar -p$_MYSQL_SONAR_PASSWORD < $_SONAR_GGAS_SQL_FILE
        else
          message "Alert" "$_SONAR_GGAS_SQL_FILE file was not found. Import unrealized!"
        fi
      fi

      message "Notice" "User and database sonar successfully created!"
      ;;

    sonar.properties)
      _PROPERTIES_FILE="$_PROPERTIES_FOLDER/sonar.properties"

      [ ! -e "$_PROPERTIES_FILE" ] && message "Alert" "The properties file '$_PROPERTIES_FILE' was not found!"

      _SERVER_ADDRESS=$(input "Enter the address and port of the MySQL Server" "$_CONNECTION_ADDRESS_MYSQL")
      [ $? -eq 1 ] && main
      [ -z "$_SERVER_ADDRESS" ] && message "Alert" "The server address can not be blank!"

      _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
      [ $? -eq 1 ] && main
      [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

      [ "$_SONAR_OPTION" = "OTHER" ] && _GGAS_USER="sonar"

      change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.username=$_GGAS_USER" "sonar.jdbc.username=sonar"
      change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.password=$_GGAS_USER" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
      change_file "replace" "$_PROPERTIES_FILE" "$_CONNECTION_ADDRESS_MYSQL" "$_SERVER_ADDRESS"
      change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

      service sonar restart

      message "Notice" "Connection to the database configured!"
      ;;
  esac
}

install_sonar_scanner () {
  _SCANNER_VERSION=$(input "Enter the version of the Sonar Scanner" "$_SCANNER_VERSION_DEFAULT")
  [ $? -eq 1 ] && main
  [ -z "$_SCANNER_VERSION" ] && message "Alert" "The Sonar Scanner version can not be blank!"

  _HOST_ADDRESS=$(input "Enter the address of the Sonar Server" "$_DEFAULT_HOST")
  [ $? -eq 1 ] && main
  [ -z "$_HOST_ADDRESS" ] && message "Alert" "The server address can not be blank!"

  if [ "$_SONAR_OPTION" = "QUBE" ]; then
    _USER_TOKEN=$(input "Enter the user token in sonar")
    [ $? -eq 1 ] && main
    [ -z "$_USER_TOKEN" ] && message "Alert" "The user token can not be blank!"

  elif [ "$_SONAR_OPTION" = "OTHER" ]; then
    _SERVER_ADDRESS=$(input "Enter the address and port of the MySQL Server" "$_CONNECTION_ADDRESS_MYSQL")
    [ $? -eq 1 ] && main
    [ -z "$_SERVER_ADDRESS" ] && message "Alert" "The server address can not be blank!"

    _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
    [ $? -eq 1 ] && main
    [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

  fi

  _SCANNER_ZIP_FILE="sonar-scanner-$_SCANNER_VERSION.zip"

  wget "https://sonarsource.bintray.com/Distribution/sonar-scanner-cli/$_SCANNER_ZIP_FILE"

  unzip $_SCANNER_ZIP_FILE
  rm $_SCANNER_ZIP_FILE

  mv "sonar-scanner-$_SCANNER_VERSION" /opt/
  ln -sf "/opt/sonar-scanner-$_SCANNER_VERSION" /opt/sonar-scanner

  _PROPERTIES_FILE="/opt/sonar-scanner/conf/sonar-scanner.properties"

  change_file "replace" "$_PROPERTIES_FILE" "^#sonar.host.url=$_DEFAULT_HOST" "sonar.host.url=$_HOST_ADDRESS"

  if [ "$_SONAR_OPTION" = "QUBE" ]; then
    echo "sonar.login=$_USER_TOKEN" >> $_PROPERTIES_FILE

  elif [ "$_SONAR_OPTION" = "OTHER" ]; then
    change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.username=sonar" "sonar.jdbc.username=sonar"
    change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.password=sonar" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
    change_file "replace" "$_PROPERTIES_FILE" "$_CONNECTION_ADDRESS_MYSQL" "$_SERVER_ADDRESS"
    change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

  fi

  message "Notice" "Sonar Scanner successfully installed!"
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input "Enter the domain of Sonar" "sonar.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input "Enter the host of Sonar server" "$_NGINX_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > sonar.conf

    change_file "replace" "sonar.conf" "APP" "sonar"
    change_file "replace" "sonar.conf" "DOMAIN" "$_DOMAIN"
    change_file "replace" "sonar.conf" "HOST" "$_HOST"

    mv sonar.conf /etc/nginx/conf.d/
    rm sonar.conf*

    service nginx restart

    message "Notice" "The host is successfully configured in NGINX!"
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
  tool_check dialog
  tool_check unzip

  _SONAR_OPTION=$(menu "Select the sonar source" "$_SONAR_SOURCE_LIST")

  if [ -z "$_SONAR_OPTION" ]; then
    clear && exit 0
  else
    _TEXT="_SONAR_SOURCE_$_SONAR_OPTION"
    _TEXT=$(echo "${!_TEXT}")
    _TITLE="--backtitle \"Tools Installer - $_APP_NAME - $_TEXT | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""

    main
  fi
}

setup
type_menu
