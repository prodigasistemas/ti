#!/bin/bash
# http://docs.sonarqube.org/display/SONAR/Installing+the+Server
# http://sonar-pkg.sourceforge.net
# http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern
# http://stackoverflow.com/questions/2634590/bash-script-variable-inside-variable
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

_URL_CENTRAL="http://prodigasistemas.github.io"
_SONAR_FOLDER="/opt/sonar"
_PROPERTIES_FOLDER="$_SONAR_FOLDER/conf"
_DEFAULT_HOST="http://localhost:9000"
_CONNECTION_ADDRESS_MYSQL="localhost:3306"
_RUNNER_VERSION_DEFAULT="2.4"

_SONAR_GGAS_VERSION="5.0"
_SONAR_GGAS_FILE="sonarqube-$_SONAR_GGAS_VERSION.tar.gz"

_SONAR_SOURCE_QUBE="Install and configure SonarQube from www.sonarqube.org"
_SONAR_SOURCE_GGAS="Install and configure SonarQube $_SONAR_GGAS_VERSION from sonar.ggas.com.br"
_SONAR_SOURCE_LIST="QUBE '$_SONAR_SOURCE_QUBE' GGAS '$_SONAR_SOURCE_GGAS'"

_OPTIONS_LIST="install_sonar 'Install the Sonar Server' \
               configure_database 'Configure connection to MySQL database' \
               install_sonar_runner 'Install the Sonar Runner' \
               configure_nginx 'Configure host on NGINX'"

_OPTIONS_DATABASE="database 'Create the user and sonar database' \
                   sonar.properties 'Configure the connection to the database'"

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -is | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get --force-yes"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
  fi

  _TITLE="--backtitle \"Sonar installation | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
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

  sed -i$_BACKUP -e "s|$2|$3|g" $1
}

run_as_root () {
  su -c "$1"
}

mysql_as_root () {
  mysql -h $1 -u root -p$2 -e "$3" 2> /dev/null
}

install_sonar_qube () {
  case $_OS_TYPE in
    deb)
      run_as_root "echo deb http://downloads.sourceforge.net/project/sonar-pkg/deb binary/ > /etc/apt/sources.list.d/sonar.list"

      $_PACKAGE_COMMAND update
      ;;
    rpm)
      wget -O /etc/yum.repos.d/sonar.repo http://downloads.sourceforge.net/project/sonar-pkg/rpm/sonar.repo
      ;;
  esac

  $_PACKAGE_COMMAND -y install sonar
}

install_sonar_ggas () {
  wget "http://sonar.ggas.com.br/download/$_SONAR_GGAS_FILE"
  tar -xvzf "$_SONAR_GGAS_FILE"
  rm "$_SONAR_GGAS_FILE"

  mv "sonarqube-$_SONAR_GGAS_VERSION" $_SONAR_FOLDER
  mv "$_SONAR_FOLDER/conf/sonar.properties_old" "$_SONAR_FOLDER/conf/sonar.properties"

  ln -sf "$_SONAR_FOLDER/bin/linux-x86-$_OS_ARCH/sonar.sh" /etc/init.d/sonar

  update-rc.d sonar defaults
  service sonar start
}

install_sonar () {
  _JAVA_PATH=$(input "Enter the path of Java 8" "/opt/java-oracle-8/bin/java")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_PATH" ] && message "Alert" "The Java 8 path can not be blank!"

  if [ -e "$_SONAR_FOLDER" ] && [ -d "$_SONAR_FOLDER" ]; then
    dialog --yesno "The $_SONAR_FOLDER already exists. To proceed, it will be deleted, right?" 0 0
    [ $? -eq 1 ] && main

    rm -rf $_SONAR_FOLDER
  fi

  case $_SONAR_OPTION in
    QUBE)
      install_sonar_qube
      ;;
    GGAS)
      install_sonar_ggas
      ;;
  esac

  change_file "$_PROPERTIES_FOLDER/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_PATH"

  if [ $_SONAR_OPTION = "QUBE" ] && [ $_OS_TYPE = "rpm" ]; then
    service sonar start
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
      [ -z "$_MYSQL_ROOT_PASSWORD" ] && message "Alert" "The root password can not be blank!"

      _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
      [ $? -eq 1 ] && main
      [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

      mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "CREATE DATABASE IF NOT EXISTS sonar;"
      mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "CREATE USER sonar@$_HOST_CONNECTION IDENTIFIED BY '$_MYSQL_SONAR_PASSWORD';"
      mysql_as_root $_HOST_CONNECTION $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON sonar.* TO sonar@$_HOST_CONNECTION WITH GRANT OPTION; FLUSH PRIVILEGES;"

      if [ $_SONAR_OPTION = "GGAS" ]; then
        wget http://sonar.ggas.com.br/download/sonar.sql

        if [ -e "sonar.sql" ]; then
          mysql -h $_HOST_CONNECTION -u sonar -p$_MYSQL_SONAR_PASSWORD < sonar.sql
        else
          message "Alert" "sonar.sql file was not found. Import unrealized!"
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

      [ $_SONAR_OPTION = "GGAS" ] && _GGAS_USER="sonar"

      change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.username=$_GGAS_USER" "sonar.jdbc.username=sonar"
      change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.password=$_GGAS_USER" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
      change_file "$_PROPERTIES_FILE" "$_CONNECTION_ADDRESS_MYSQL" "$_SERVER_ADDRESS"
      change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

      service sonar restart

      message "Notice" "Connection to the database configured!"
      ;;
  esac
}

install_sonar_runner () {
  _RUNNER_VERSION=$(input "Enter the version of the Sonar Runner" "$_RUNNER_VERSION_DEFAULT")
  [ $? -eq 1 ] && main
  [ -z "$_RUNNER_VERSION" ] && message "Alert" "The Sonar Runner version can not be blank!"

  _HOST_ADDRESS=$(input "Enter the address of the Sonar Server" "$_DEFAULT_HOST")
  [ $? -eq 1 ] && main
  [ -z "$_HOST_ADDRESS" ] && message "Alert" "The server address can not be blank!"

  if [ $_SONAR_OPTION = "QUBE" ]; then
    _USER_TOKEN=$(input "Enter the user token in sonar")
    [ $? -eq 1 ] && main
    [ -z "$_USER_TOKEN" ] && message "Alert" "The user token can not be blank!"

  elif [ $_SONAR_OPTION = "GGAS" ]; then
    _SERVER_ADDRESS=$(input "Enter the address and port of the MySQL Server" "$_CONNECTION_ADDRESS_MYSQL")
    [ $? -eq 1 ] && main
    [ -z "$_SERVER_ADDRESS" ] && message "Alert" "The server address can not be blank!"

    _MYSQL_SONAR_PASSWORD=$(input "Enter the password of the sonar user in MySQL")
    [ $? -eq 1 ] && main
    [ -z "$_MYSQL_SONAR_PASSWORD" ] && message "Alert" "The sonar password can not be blank!"

  fi

  _RUNNER_ZIP_FILE="sonar-runner-dist-$_RUNNER_VERSION.zip"

  wget "http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/$_RUNNER_VERSION/$_RUNNER_ZIP_FILE"

  unzip $_RUNNER_ZIP_FILE
  rm $_RUNNER_ZIP_FILE

  mv "sonar-runner-$_RUNNER_VERSION" /opt/sonar-runner

  _PROPERTIES_FILE="/opt/sonar-runner/conf/sonar-runner.properties"

  change_file "$_PROPERTIES_FILE" "^#sonar.host.url=$_DEFAULT_HOST" "sonar.host.url=$_HOST_ADDRESS"

  if [ $_SONAR_OPTION = "QUBE" ]; then
    change_file "$_PROPERTIES_FILE" "^#sonar.login=admin" "sonar.login=$_USER_TOKEN"

  elif [ $_SONAR_OPTION = "GGAS" ]; then
    change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.username=sonar" "sonar.jdbc.username=sonar"
    change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.password=sonar" "sonar.jdbc.password=$_MYSQL_SONAR_PASSWORD"
    change_file "$_PROPERTIES_FILE" "$_CONNECTION_ADDRESS_MYSQL" "$_SERVER_ADDRESS"
    change_file "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:mysql" "sonar.jdbc.url=jdbc:mysql"

  fi

  message "Notice" "Sonar Runner successfully installed!"
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input "Enter the domain of Sonar" "sonar.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input "Enter the host of Sonar server" "$_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_URL_CENTRAL/scripts/templates/nginx/redirect.conf" > sonar.conf

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
    _TITLE="--backtitle \"$_TEXT - OS: $_OS_NAME\""

    main
  fi
}

os_check
type_menu
