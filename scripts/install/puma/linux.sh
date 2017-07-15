#!/bin/bash

# https://github.com/puma/puma/blob/master/tools/jungle/upstart/README.md

export _APP_NAME="Puma"
_OPTIONS_LIST="install_puma 'Install Puma Manager'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="https://prodigasistemas.github.io"

  ping -c 1 "$(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g' | cut -d: -f1)" > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

install_puma () {
  _TEMPLATES="$_CENTRAL_URL_TOOLS/scripts/templates/puma"

  confirm "Do you confirm the installation of Puma Manager (Upstart)?"
  [ $? -eq 1 ] && main

  curl -sS "$_TEMPLATES/upstart/puma.conf" > "/etc/init/puma.conf"
  curl -sS "$_TEMPLATES/upstart/puma-manager.conf" > "/etc/init/puma-manager.conf"

  touch /etc/puma.conf

  [ $? -eq 0 ] && message "Notice" "Puma Manager successfully installed! Add your apps in /etc/puma.conf"
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
