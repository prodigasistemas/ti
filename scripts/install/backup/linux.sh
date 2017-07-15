#!/bin/bash

export _APP_NAME="Backup"
_FOLDER="/var/tools-backup"
_OPTIONS_LIST="install_backup 'Install or update Backup' \
               about 'About Backup'"

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
  _TEMPLATES="$_CENTRAL_URL_TOOLS/scripts/templates/backup"

  if [ -e "$_FOLDER" ]; then
    _OPERATION="update of backup.sh and hosts/example.list"
  else
    _OPERATION="installation of Backup"
  fi

  confirm "Do you confirm the $_OPERATION?"
  [ $? -eq 1 ] && main

  [ ! -e "$_FOLDER" ] && mkdir -p $_FOLDER
  [ ! -e "$_FOLDER/hosts" ] && mkdir -p "$_FOLDER/hosts"
  [ ! -e "$_FOLDER/logs" ] && mkdir -p "$_FOLDER/logs"

  cd $_FOLDER

  wget -q "$_TEMPLATES/$_SCRIPT"

  [ -e "$_FOLDER/$_SCRIPT.1" ] && mv "$_FOLDER/$_SCRIPT.1" "$_FOLDER/$_SCRIPT"

  chmod +x "$_FOLDER/$_SCRIPT"

  [ ! -e "backup.conf" ] && wget -q "$_TEMPLATES/backup.conf"
  [ ! -e "hosts.list" ] && wget -q "$_TEMPLATES/hosts.list"

  cd "$_FOLDER/hosts"
  wget -q "$_TEMPLATES/hosts/example.list"

  [ -e "$_FOLDER/hosts/example.list.1" ] && mv "$_FOLDER/hosts/example.list.1" "$_FOLDER/hosts/example.list"

  _CRON_USER_FILE="/var/spool/cron/crontabs/$_USER_LOGGED"

  _FIND_RECORD=$(grep "$_FOLDER/$_SCRIPT" "$_CRON_USER_FILE")

  if [ -z "$_FIND_RECORD" ]; then
    su -c "echo \"0 23 * * * $_FOLDER/$_SCRIPT\" >> $_CRON_USER_FILE"

    chown "$_USER_LOGGED":"$_USER_LOGGED" "$_CRON_USER_FILE"
  fi

  chown "$_USER_LOGGED":"$_USER_LOGGED" -R "$_FOLDER"

  [ $? -eq 0 ] && message "Notice" "Backup successfully installed in '$_FOLDER'. See about section for more details."
}

about () {
  message "Notice" "About Backup:\n\n \
           Installed in '$_FOLDER'\n\n \
           Files:\n\n \
           backup.sh   - management of databases and folders backup, running in cron job\n \
           backup.conf - definitions of rsync host, aws bucket and max files preservation\n \
           hosts.list  - list of hosts with your connections (via ssh)\n\n \
           Folders:\n\n \
           hosts   - each host in 'hosts.list' hold your configuration file. See 'example.list'\n \
           logs    - logs per host and general synchronization\n \
           storage - store compressed backup assets"
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
