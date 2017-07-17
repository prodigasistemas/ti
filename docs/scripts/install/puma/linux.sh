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
  _TEMPLATES="$_CENTRAL_URL_TOOLS/scripts/templates/puma"

  _SERVICES_LIST="upstart 'via Upstart for Ubuntu <= 14' \
                  init.d 'via init.d for Ubuntu >= 16'"

  _SERVICE=$(menu "Select the option" "$_SERVICES_LIST")

  [ -z "$_SERVICE" ] && main

  confirm "Do you confirm the installation of Puma Service via $_SERVICE?"
  [ $? -eq 1 ] && main

  case $_SERVICE in
    upstart)
      _MESSAGE="app_path"

      curl -sS "$_TEMPLATES/$_SERVICE/puma.conf" > /etc/init/puma.conf
      curl -sS "$_TEMPLATES/$_SERVICE/puma-manager.conf" > /etc/init/puma-manager.conf
      ;;

    init.d)
      _MESSAGE="app_path,username"

      curl -sS "$_TEMPLATES/$_SERVICE/run-puma" > /usr/local/bin/run-puma
      curl -sS "$_TEMPLATES/$_SERVICE/puma" > /etc/init.d/puma

      chmod +x /usr/local/bin/run-puma /etc/init.d/puma

      admin_service puma register
      ;;
  esac

  touch /etc/puma.conf

  [ $? -eq 0 ] && message "Notice" "Puma Service successfully installed! Add your apps in /etc/puma.conf with $_MESSAGE"
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
