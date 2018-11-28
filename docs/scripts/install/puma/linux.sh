#!/bin/bash

# https://github.com/puma/puma/tree/master/tools/jungle/upstart
# https://github.com/puma/puma/tree/master/tools/jungle/init.d

export _APP_NAME="Puma"
_OPTIONS_LIST="install_puma 'Install Puma Service'"

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

install_puma () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  _TEMPLATES="$_CENTRAL_URL_TOOLS/scripts/templates/puma"

  which systemd

  if [ $? -eq 0 ]; then
    _SERVICE="systemd"
  else
    _SERVICE="upstart"
  fi

  _PUMA_SERVICE_NAME=$(input_field "puma.service.name" "Enter the puma service name")
  [ $? -eq 1 ] && main
  [ -z "$_PUMA_SERVICE_NAME" ] && message "Alert" "The service name can not be blank!"

  _PUMA_USER_NAME=$(input_field "puma.user.name" "Enter the puma user name" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_PUMA_USER_NAME" ] && message "Alert" "The user name can not be blank!"

  confirm "Do you confirm the installation of $_PUMA_SERVICE_NAME Puma Service?"
  [ $? -eq 1 ] && main

  case $_SERVICE in
    upstart)
      curl -sS "$_TEMPLATES/$_SERVICE/puma.conf" > /etc/init/puma.conf
      curl -sS "$_TEMPLATES/$_SERVICE/puma-manager.conf" > /etc/init/puma-manager.conf

      sed -i "s/USER_NAME/$_PUMA_USER_NAME/g" /etc/init/puma.conf

      _PUMA_CONF=/etc/puma.conf
      _PUMA_APP_PATH=/var/www/$_PUMA_SERVICE_NAME

      grep $_PUMA_APP_PATH $_PUMA_CONF > /dev/null 2> /dev/null

      if [ $? -ne 0 ]; then
        su -c "echo $_PUMA_APP_PATH >> $_PUMA_CONF"
      fi
      ;;

    systemd)
      _PUMA_SERVICE=puma-$_PUMA_SERVICE_NAME.service

      curl -sS "$_TEMPLATES/$_SERVICE/puma.service" > /tmp/puma.service

      mv /tmp/puma.service /tmp/$_PUMA_SERVICE

      sed -i "s/APP_NAME/$_PUMA_SERVICE_NAME/g" /tmp/$_PUMA_SERVICE

      sed -i "s/USER_NAME/$_PUMA_USER_NAME/g" /tmp/$_PUMA_SERVICE

      mv /tmp/$_PUMA_SERVICE /etc/systemd/system

      admin_service "puma-$_PUMA_SERVICE_NAME" register

      admin_service "puma-$_PUMA_SERVICE_NAME" start
      ;;
  esac

  [ $? -eq 0 ] && message "Notice" "$_PUMA_SERVICE_NAME Puma Service successfully installed!"
}

main () {
  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app puma)" ] && install_puma
  fi
}

setup
main
