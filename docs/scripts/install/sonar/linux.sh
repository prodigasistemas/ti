#!/bin/bash
# http://docs.sonarqube.org/display/SONAR/Installing+the+Server
# http://sonar-pkg.sourceforge.net
# http://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern
# http://stackoverflow.com/questions/2634590/bash-script-variable-inside-variable
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

export _APP_NAME="SonarQube"
_SONAR_LAST_VERSION="6.7.6"

_SONAR_FOLDER="/opt/sonar"
_DOWNLOADS_FOLDER="$_SONAR_FOLDER/downloads"
_VERSIONS_FOLDER="$_SONAR_FOLDER/versions"
_CURRENT_FOLDER="$_SONAR_FOLDER/current"

_NGINX_DEFAULT_HOST="localhost:9000"
_DEFAULT_HOST="http://$_NGINX_DEFAULT_HOST"

_OPTIONS_LIST="install_sonar 'Install the Sonar Server' \
               configure_database 'Configure connection to PostgreSQL database' \
               configure_nginx 'Configure host on NGINX'"

_OPTIONS_DATABASE="create_sonar_database 'Create the user and sonar database' \
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

db_host_input () {
  _DB_HOST=$(input_field "sonar.postgresql.host" "Enter the host of the PostgreSQL Server" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_DB_HOST" ] && message "Alert" "The host of the PostgreSQL Server can not be blank!"
}

db_connection_input () {
  db_host_input

  _DB_PORT=$(input_field "sonar.postgresql.port" "Enter the port of the PostgreSQL Server" "5432")
  [ $? -eq 1 ] && main
  [ -z "$_DB_PORT" ] && message "Alert" "The port of the PostgreSQL Server can not be blank!"
}

install_sonar () {
  _java_version=8

  java_check $_java_version

  _JAVA_HOME=$(get_java_home $_java_version)

  _JAVA_COMMAND=$(input_field "[default]" "Enter the path of command Java $_java_version" "$_JAVA_HOME/bin/java")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_COMMAND" ] && message "Alert" "The Java command can not be blank!"

  _SONAR_VERSION=$(input_field "sonar.version" "Enter the sonar version" "$_SONAR_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_SONAR_VERSION" ] && message "Alert" "The sonar version can not be blank!"

  confirm "Confirm installation SonarQube $_SONAR_VERSION?" "Sonar installer"
  [ $? -eq 1 ] && main

  print_colorful yellow bold "> Downloading SonarQube $_SONAR_VERSION..."

  _SONAR_PACKAGE=sonarqube-$_SONAR_VERSION.zip

  mkdir -p $_SONAR_FOLDER/{downloads,versions}

  [ -e "$_VERSIONS_FOLDER/$_SONAR_VERSION" ] && message "Alert" "Sonar $_SONAR_VERSION is already installed."

  cd $_DOWNLOADS_FOLDER

  if [ ! -e "$_DOWNLOADS_FOLDER/$_SONAR_PACKAGE" ]; then
    wget "https://binaries.sonarsource.com/Distribution/sonarqube/$_SONAR_PACKAGE"

    [ $? -ne 0 ] && message "Error" "Download of file $_SONAR_PACKAGE unrealized!"
  fi

  unzip -oq $_SONAR_PACKAGE

  mv "sonarqube-$_SONAR_VERSION" "$_VERSIONS_FOLDER/$_SONAR_VERSION"

  make_symbolic_link "$_VERSIONS_FOLDER/$_SONAR_VERSION" "$_CURRENT_FOLDER"

  change_file "replace" "$_CURRENT_FOLDER/conf/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_HOME/bin/java"

  change_file "replace" "$_CURRENT_FOLDER/bin/linux-x86-$_OS_ARCH/sonar.sh" "^#RUN_AS_USER=" "RUN_AS_USER=sonar"

  groupadd sonar

  useradd sonar -g sonar -M

  chown sonar: -R "$_SONAR_FOLDER"

  make_symbolic_link "$_CURRENT_FOLDER/bin/linux-x86-$_OS_ARCH/sonar.sh" "/etc/init.d/sonar"

  admin_service sonar register

  admin_service sonar restart

  [ $? -eq 0 ] && message "Notice" "SonarQube successfully installed!"
}

create_sonar_database () {
  print_colorful white bold "> Configuring database..."

  cd $_SONAR_FOLDER

  echo "postgresql.database.name = sonar" > recipe.ti
  echo "postgresql.database.user.name = sonar" >> recipe.ti
  echo "postgresql.database.user.password = sonar" >> recipe.ti

  curl -sS $_CENTRAL_URL_TOOLS/scripts/install/postgresql/linux.sh | bash

  delete_file recipe.ti

  [ $? -eq 0 ] && message "Notice" "User and database sonar successfully created!"
}

configure_sonar_properties () {
  _PROPERTIES_FILE="$_CURRENT_FOLDER/conf/sonar.properties"

  [ ! -e "$_PROPERTIES_FILE" ] && message "Alert" "The properties file '$_PROPERTIES_FILE' was not found!"

  db_connection_input

  change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.username=" "sonar.jdbc.username=sonar"
  change_file "replace" "$_PROPERTIES_FILE" "^#sonar.jdbc.password=" "sonar.jdbc.password=sonar"
  change_file "append" "$_PROPERTIES_FILE" "^#sonar.jdbc.url=jdbc:postgresql" "sonar.jdbc.url=jdbc:postgresql://$_DB_HOST:$_DB_PORT/sonar"

  admin_service sonar restart

  [ $? -eq 0 ] && message "Notice" "Connection to the database configured!"
}

configure_database () {
  _OPTION=$(menu "Select which configuration" "$_OPTIONS_DATABASE")
  [ -z "$_OPTION" ] && main

  $_OPTION
}

configure_nginx () {
  which nginx > /dev/null
  [ $? -ne 0 ] && message "Alert" "NGINX Web Server is not installed!"

  _DOMAIN=$(input_field "sonar.nginx.domain" "Enter the domain of Sonar" "sonar.company.gov")
  [ $? -eq 1 ] && main
  [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

  _HOST=$(input_field "sonar.nginx.host" "Enter the host of Sonar server" "$_NGINX_DEFAULT_HOST")
  [ $? -eq 1 ] && main
  [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

  if [ ! -e "/etc/nginx/conf.d/sonar.conf" ]; then
    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > sonar.conf

    change_file "replace" "sonar.conf" "APP" "sonar"
    change_file "replace" "sonar.conf" "DOMAIN" "$_DOMAIN"
    change_file "replace" "sonar.conf" "HOST" "$_HOST"

    mv sonar.conf /etc/nginx/conf.d/
    rm $_SED_BACKUP_FOLDER/sonar.conf*

    admin_service nginx reload

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
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

main () {
  tool_check curl
  tool_check unzip
  tool_check wget

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_MAIN_OPTION" ]; then
      clear && exit 0
    else
      $_MAIN_OPTION
    fi
  else
    [ -n "$(search_app sonar)" ] && install_sonar
    if [ -n "$(search_app sonar.postgresql)" ]; then
      create_sonar_database
      configure_sonar_properties
    fi
    [ -n "$(search_app sonar.nginx)" ] && configure_nginx
  fi
}

setup
main
