#!/bin/bash

# https://github.com/mperham/sidekiq/wiki/Deploying-to-Ubuntu
# https://github.com/mperham/sidekiq/wiki/Deployment

export _APP_NAME="Sidekiq"
_OPTIONS_LIST="install_sidekiq 'Install Sidekiq Queue Service'"

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

install_sidekiq () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  _TEMPLATES="$_CENTRAL_URL_TOOLS/scripts/templates/sidekiq"

  which systemd > /dev/null

  if [ $? -eq 0 ]; then
    _SERVICE="systemd"
  else
    _SERVICE="upstart"
  fi

  _SIDEKIQ_SERVICE_NAME=$(input_field "sidekiq.service.name" "Enter the sidekiq service name")
  [ $? -eq 1 ] && main
  [ -z "$_SIDEKIQ_SERVICE_NAME" ] && message "Alert" "The service name can not be blank!"

  _SIDEKIQ_USER_NAME=$(input_field "sidekiq.user.name" "Enter the sidekiq user name" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_SIDEKIQ_USER_NAME" ] && message "Alert" "The user name can not be blank!"

  confirm "Do you confirm the installation of $_SIDEKIQ_SERVICE_NAME Sidekiq Queue Service?"
  [ $? -eq 1 ] && main

  case $_SERVICE in
    upstart)
      _SIDEKIQ_CONF="/etc/init/sidekiq-$_SIDEKIQ_SERVICE_NAME.conf"

      curl -sS "$_TEMPLATES/$_SERVICE/sidekiq.conf" > $_SIDEKIQ_CONF

      curl -sS "$_TEMPLATES/$_SERVICE/workers.conf" > /etc/init/workers.conf

      sed -i "s/APP_NAME/$_SIDEKIQ_SERVICE_NAME/g" $_SIDEKIQ_CONF

      sed -i "s/USER_NAME/$_SIDEKIQ_USER_NAME/g" $_SIDEKIQ_CONF
      ;;

    systemd)
      _SIDEKIQ_SERVICE=sidekiq-$_SIDEKIQ_SERVICE_NAME.service

      curl -sS "$_TEMPLATES/$_SERVICE/sidekiq.service" > /tmp/sidekiq.service

      mv /tmp/sidekiq.service /tmp/$_SIDEKIQ_SERVICE

      sed -i "s/APP_NAME/$_SIDEKIQ_SERVICE_NAME/g" /tmp/$_SIDEKIQ_SERVICE

      sed -i "s/USER_NAME/$_SIDEKIQ_USER_NAME/g" /tmp/$_SIDEKIQ_SERVICE

      mv /tmp/$_SIDEKIQ_SERVICE /etc/systemd/system

      admin_service "sidekiq-$_SIDEKIQ_SERVICE_NAME" register

      admin_service "sidekiq-$_SIDEKIQ_SERVICE_NAME" start
      ;;
  esac

  [ $? -eq 0 ] && message "Notice" "$_SIDEKIQ_SERVICE_NAME Sidekiq Queue Service successfully installed!"
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
    [ -n "$(search_app sidekiq)" ] && install_sidekiq
  fi
}

setup
main
