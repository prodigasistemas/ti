#!/bin/bash

# http://archiva.apache.org/docs/2.2.1/adminguide/standalone.html

export _APP_NAME="Archiva"
_CURRENT_VERSION="2.2.3"
_ARCHIVA_FOLDER="/opt/apache-archiva"
_DEFAULT_PORT="8070"
_OPTIONS_LIST="install_archiva 'Install Archiva' \
               configure_nginx 'Configure host on NGINX'"

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

install_archiva () {
  _JAVA_VERSION=8
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  java_check "$_JAVA_VERSION"

  _JAVA_HOME=$(get_java_home $_JAVA_VERSION)

  _VERSION=$(input_field "archiva.version" "Enter the version for $_APP_NAME" "$_CURRENT_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && message "Alert" "The version can not be blank!"

  _HTTP_PORT=$(input_field "archiva.http.port" "Enter the http port for $_APP_NAME" "$_DEFAULT_PORT")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  _OWNER=$(input_field "archiva.owner.name" "Enter the $_APP_NAME owner name" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_OWNER" ] && message "Alert" "The $_APP_NAME owner name can not be blank!"

  _SETTINGS_ADMIN_NAME=$(input_field "archiva.settings.admin.name" "Enter the $_APP_NAME admin name" "admin")
  [ $? -eq 1 ] && main
  [ -z "$_SETTINGS_ADMIN_NAME" ] && message "Alert" "The $_APP_NAME admin name can not be blank!"

  _SETTINGS_ADMIN_PASSWORD=$(input_field "archiva.settings.admin.password" "Enter the $_APP_NAME admin password")
  [ $? -eq 1 ] && main
  [ -z "$_SETTINGS_ADMIN_PASSWORD" ] && message "Alert" "The $_APP_NAME admin password can not be blank!"

  _SETTINGS_URL_ADDRESS=$(input_field "archiva.settings.url.address" "Enter the $_APP_NAME url address" "archiva.corporate.com")
  [ $? -eq 1 ] && main
  [ -z "$_SETTINGS_URL_ADDRESS" ] && message "Alert" "The $_APP_NAME url address can not be blank!"

  confirm "Do you confirm the installation of $_APP_NAME?"
  [ $? -eq 1 ] && main

  admin_service archiva stop 2> /dev/null

  wget "http://archive.apache.org/dist/archiva/$_VERSION/binaries/apache-archiva-$_VERSION-bin.zip"

  [ $? -ne 0 ] && message "Error" "Download of apache-archiva-$_VERSION-bin.zip not realized!"

  unzip -oq "apache-archiva-$_VERSION-bin.zip"

  rm "apache-archiva-$_VERSION-bin.zip"

  backup_folder $_ARCHIVA_FOLDER

  mv "apache-archiva-$_VERSION" $_ARCHIVA_FOLDER

  change_file replace "$_ARCHIVA_FOLDER/conf/jetty.xml" "<Set name=\"port\"><SystemProperty name=\"jetty.port\" default=\"8080\"/></Set>" "<Set name=\"port\"><SystemProperty name=\"jetty.port\" default=\"$_HTTP_PORT\"/></Set>"

  change_file replace "$_ARCHIVA_FOLDER/conf/wrapper.conf" "^wrapper.java.command=java" "wrapper.java.command=$_JAVA_HOME/bin/java"

  change_file replace "$_ARCHIVA_FOLDER/bin/archiva" "#RUN_AS_USER=" "RUN_AS_USER=$_OWNER"

  _SETTINGS_FILE=settings.xml
  _TMP_SETTINGS="/tmp/$_SETTINGS_FILE"
  _USER_FOLDER=$(grep $_OWNER /etc/passwd | cut -d: -f6)
  _M2_FOLDER="$_USER_FOLDER/.m2"

  curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/archiva/$_SETTINGS_FILE" > $_TMP_SETTINGS

  change_file replace $_TMP_SETTINGS USERNAME "$_SETTINGS_ADMIN_NAME"
  change_file replace $_TMP_SETTINGS PASSWORD "$_SETTINGS_ADMIN_PASSWORD"
  change_file replace $_TMP_SETTINGS URL_ADDRESS "$_SETTINGS_URL_ADDRESS"

  if [ ! -e "$_M2_FOLDER" ]; then
    mkdir -p "$_M2_FOLDER"
    chown "$_OWNER":"$_OWNER" "$_M2_FOLDER"
  fi

  if [ -e "$_M2_FOLDER/$_SETTINGS_FILE" ]; then
    cp "$_M2_FOLDER/$_SETTINGS_FILE" "$_M2_FOLDER/$_SETTINGS_FILE.backup"
    chown "$_OWNER":"$_OWNER" "$_M2_FOLDER/$_SETTINGS_FILE.backup"
  fi

  mv $_TMP_SETTINGS "$_M2_FOLDER"

  rm $_TMP_SETTINGS.backup*

  chown "$_OWNER":"$_OWNER" "$_M2_FOLDER/$_SETTINGS_FILE"

  chown "$_OWNER":"$_OWNER" -R "$_ARCHIVA_FOLDER"

  ln -sf $_ARCHIVA_FOLDER/bin/archiva /etc/init.d/

  admin_service archiva register

  admin_service archiva restart

  [ $? -eq 0 ] && message "Notice" "$_APP_NAME successfully installed!"
}

configure_nginx () {
  _DEFAULT_HOST="localhost:$_DEFAULT_PORT"

  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "archiva.nginx.domain" "Enter the domain of $_APP_NAME" "archiva.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input_field "archiva.nginx.host" "Enter the host of $_APP_NAME" "$_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    confirm "Do you confirm the configuration of NGINX host?"
    [ $? -eq 1 ] && main

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > archiva.conf

    change_file replace archiva.conf APP archiva
    change_file replace archiva.conf DOMAIN "$_DOMAIN"
    change_file replace archiva.conf HOST "$_HOST"

    mv archiva.conf /etc/nginx/conf.d/
    rm archiva.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed! $_APP_NAME host not configured!"
  fi
}

main () {
  tool_check wget
  tool_check unzip

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app archiva)" ] && install_archiva
    [ -n "$(search_app archiva.nginx)" ] && configure_nginx
  fi
}

setup
main
