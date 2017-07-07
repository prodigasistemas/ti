#!/bin/bash

export _APP_NAME="Backup"
_FOLDER="/var/tools-backup"
_OPTIONS_LIST="install_backup 'Install Backup'"

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

install_backup () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")
  _SCRIPT="backup.sh"

  confirm "Do you confirm the installation of Backup?"
  [ $? -eq 1 ] && main

  [ ! -e "$_FOLDER" ] && mkdir -p $_FOLDER
  [ ! -e "$_FOLDER/hosts" ] && mkdir -p "$_FOLDER/hosts"
  [ ! -e "$_FOLDER/logs" ] && mkdir -p "$_FOLDER/logs"

  cd $_FOLDER

  wget -q "$_CENTRAL_URL_TOOLS/scripts/templates/backup/$_SCRIPT"

  chmod +x "$_FOLDER/$_SCRIPT"

  [ ! -e "backup.conf" ] && wget -q "$_CENTRAL_URL_TOOLS/scripts/templates/backup/backup.conf"
  [ ! -e "hosts.list" ] && wget -q "$_CENTRAL_URL_TOOLS/scripts/templates/backup/hosts.list"

  cd "$_FOLDER/hosts"
  wget -q "$_CENTRAL_URL_TOOLS/scripts/templates/backup/hosts/example.host"

  _CRON_USER_FILE="/var/spool/cron/crontabs/$_USER_LOGGED"

  _FIND_RECORD=$(grep "$_FOLDER/$_SCRIPT" "$_CRON_USER_FILE")

  if [ -z "$_FIND_RECORD" ]; then
    su -c "echo \"0 23 * * * $_FOLDER/$_SCRIPT\" >> $_CRON_USER_FILE"

    chown "$_USER_LOGGED":"$_USER_LOGGED" "$_CRON_USER_FILE"
  fi

  [ $? -eq 0 ] && message "Notice" "Backup successfully installed!"
}

main () {
  tool_check wget

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app backup)" ] && install_backup
  fi
}

setup
main
