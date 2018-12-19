#!/bin/bash

export _APP_NAME="Restore"
_TOOLS_FOLDER="/opt/tools"
_FOLDER="$_TOOLS_FOLDER/backup"
_CONFIG_FILE="$_FOLDER/backup.conf"
_LOG_SYNC="$_FOLDER/logs/synchronizing.log"
_OPTIONS_LIST="perform_sync 'Synchronize server with local folder' \
               perform_restore 'Perform restore'"

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

sync_rsync () {
  tool_check rsync

  _HOST_ADDRESS=$(echo $_RSYNC_HOST | cut -d: -f1)

  run_as_user "$_USER_LOGGED" "ssh $_HOST_ADDRESS ls > /dev/null"

  [ $? -ne 0 ] && message "Error" "ssh connect to $_HOST_ADDRESS: Connection refused"

  run_as_user "$_USER_LOGGED" "rsync -CzpOurv --log-file=$_LOG_SYNC $_RSYNC_HOST/backup $_TOOLS_FOLDER >> /dev/null 2>> $_LOG_SYNC"

  chown $_USER_LOGGED: -R $_FOLDER

  chmod +x "$_FOLDER/backup.sh"

  [ $? -eq 0 ] && tailbox $_LOG_SYNC && message "Notice" "Synchronization successfully!"
}

sync_bucket () {
  tool_check awscli

  aws s3 ls "s3://$_AWS_BUCKET" > /dev/null

  [ $? -ne 0 ] && message "Alert" "The aws S3 $_AWS_BUCKET not found!"

  aws s3 sync "s3://$_AWS_BUCKET/" $_FOLDER >> $_LOG_SYNC 2>> $_LOG_SYNC

  chown $_USER_LOGGED: -R $_FOLDER

  chmod +x "$_FOLDER/backup.sh"

  [ $? -eq 0 ] && tailbox $_LOG_SYNC && message "Notice" "Synchronization successfully!"
}

perform_sync () {
  [ ! -e "$_CONFIG_FILE" ] && message "Alert" "$_CONFIG_FILE not found!"

  source "$_CONFIG_FILE"

  [ -n "$_RSYNC_HOST" ] && _SYNC_LIST="rsync '$_RSYNC_HOST' "

  [ -n "$_AWS_BUCKET" ] && _SYNC_LIST+="bucket 's3://$_AWS_BUCKET' "

  _SYNC_OPTION=$(menu "Select from" "$_SYNC_LIST")

  if [ -z "$_SYNC_OPTION" ]; then
    main
  else
    confirm "Do you confirm perform sync from $_SYNC_OPTION?"
    [ $? -eq 1 ] && perform_sync

    sync_$_SYNC_OPTION

    perform_sync
  fi
}

perform_restore () {
  message "Notice" "Wait!"

  # sed '/^#/ d; /^$/ d' /opt/tools/backup/hosts.list
  # sed '/^#/ d; /^$/ d' /opt/tools/backup/hosts/bionic.list
}

main () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  fi
}

setup
main
