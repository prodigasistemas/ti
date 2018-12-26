#!/bin/bash

# https://aurelio.net/shell/dialog/#itensescolhidos
# http://xmodulo.com/create-dialog-boxes-interactive-shell-script.html

export _APP_NAME="Restore"
_TOOLS_FOLDER="/opt/tools"
_FOLDER="$_TOOLS_FOLDER/backup"
_CONFIG_FILE="$_FOLDER/backup.conf"
_LOG_SYNC="$_FOLDER/logs/synchronizing.log"
_OPTIONS_LIST="perform_sync 'Synchronize server with local folder' \
               select_files 'Select files from restore'"

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
  _command_name=$1
  _destination=$2
  _command_line=$3
  _access="$_HOST_USER@$_HOST_ADDRESS"

  if [ "$_HOST_ADDRESS" = "local" ]; then
    if [ -z "$(command -v "$_command_name")" ]; then
      message "Error" "$_command_name is not installed!"
    else
      eval "$_command_line" >> "$_LOG_FILE" 2>> "$_LOG_FILE"

      if [ $? -eq 0 ] && [ -e "/tmp/$_RESTORE_FILE_NAME" ]; then
        cp "$_RESTORE_FILE" "$_destination"
      fi
    fi
  else
    _check_command=$(ssh -C -p "$_HOST_PORT" "$_access" "command -v $_command_name")

    if [ -z "$_check_command" ]; then
      message "Error" "$_command_name is not installed!"
    else
      scp -C -P "$_HOST_PORT" "$_RESTORE_FILE" "$_access:$_destination" >> "$_LOG_FILE" 2>> "$_LOG_FILE"

      if [ $? -eq 0 ]; then
        ssh -C -p "$_HOST_PORT" "$_access" "$_command_line" >> "$_LOG_FILE" 2>> "$_LOG_FILE"
      fi
    fi
  fi
}

restore_folder () {
  _RESTORE_FOLDER=$(echo $_RESTORE_FILE | cut -d/ -f3)
  _FOLDER_LIST=$(sed '/^folder:$_RESTORE_FOLDER/!d;' "$_HOST_FILE")

  if [ -n "$_FOLDER_LIST" ]; then
    _name=$(echo "$_FOLDER_LIST" | cut -d: -f2)
    _path=$(echo "$_FOLDER_LIST" | cut -d: -f3)
    _DEST="/tmp/tools/restore"

    print_colorful yellow bold "> Decompressing $_RESTORE_FILE_NAME to $_HOST_ADDRESS"

    _commands="mkdir -p $_DEST && \
               mv /tmp/$_RESTORE_FILE_NAME $_DEST \
               tar -xzf $_DEST/$_RESTORE_FILE_NAME && \
               sudo rsync -rv $_DEST/$_path/ $_path/ && \
               sudo rm -rf $_DEST"

    perform_restore "tar" "/tmp" "$_commands"
  fi
}

backup_database () {
  _RESTORE_DB_TYPE=$(echo $_RESTORE_FILE | cut -d/ -f3)
  _RESTORE_DB_NAME=$(echo $_RESTORE_FILE | cut -d/ -f4)
  _RESTORE_FILE_NAME=$(echo $_RESTORE_FILE | cut -d/ -f5)
  _DB_FIELDS=$(sed '/^database:$_RESTORE_DB_TYPE/!d; /$_RESTORE_DB_NAME/!d;' "$_HOST_FILE")

  if [ -n "$_DB_FIELDS" ]; then
    _DB_TYPE=$(echo "$_DB_FIELDS" | cut -d: -f2)
    _DB_HOST=$(echo "$_DB_FIELDS" | cut -d: -f3)
    _DB_USER=$(echo "$_DB_FIELDS" | cut -d: -f4)
    _DB_PASS=$(echo "$_DB_FIELDS" | cut -d: -f5)

    _SQL_FILE="${_RESTORE_FILE_NAME/.gz/}"

    case $_DB_TYPE in
      mysql)
        _COMMAND=mysql
        _CREATE_DB=""
        _CREATE_ROLE=""
        _DB_RESTORE="MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER $_DB_NAME"
        ;;

      postgresql)
        _COMMAND=psql
        _CREATE_ROLE="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -c \"CREATE ROLE $_RESTORE_DB_NAME LOGIN ENCRYPTED PASSWORD '$_RESTORE_DB_NAME' NOINHERIT VALID UNTIL 'infinity';\""
        _CREATE_DB="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -c \"CREATE DATABASE $_RESTORE_DB_NAME WITH OWNER=$_RESTORE_DB_NAME ENCODING='UTF8';\""
        _DB_RESTORE="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -d $_DB_NAME"
        ;;
    esac

    print_colorful yellow bold "> Restoring $_DB_TYPE database $_DB_NAME to $_HOST_ADDRESS"

    _commands="tar -xzf /tmp/$_RESTORE_FILE_NAME && \
               $_CREATE_ROLE && \
               $_CREATE_DB && \
               $_DB_RESTORE < /tmp/$_SQL_FILE && \
               rm /tmp/$_SQL_FILE*"

    perform_restore "$_COMMAND" "/tmp" "$_commands"
  fi
}

select_host () {
  _RESTORE_FILE=$1
  _RESTORE_HOST=$(echo $_RESTORE_FILE | cut -d/ -f1)
  _RESTORE_TYPE=$(echo $_RESTORE_FILE | cut -d/ -f2)

  _HOSTS_LIST="$_FOLDER/hosts.list"

  if [ -e "$_HOSTS_LIST" ]; then
    _HOST_FIELDS=$(sed '/^ *$/d; /^ *#/d; /^$_RESTORE_HOST/ !d;' $_HOSTS_LIST)

    if [ -n "$_HOST_FIELDS" ]; then
      _HOST_NAME=$(echo "$_HOST_FIELDS" | cut -d: -f1)
      _HOST_ADDRESS=$(echo "$_HOST_FIELDS" | cut -d: -f2)
      _HOST_PORT=$(echo "$_HOST_FIELDS" | cut -d: -f3)
      _HOST_USER=$(echo "$_HOST_FIELDS" | cut -d: -f4)

      _HOST_FILE="$_FOLDER/hosts/$_HOST_NAME.list"
      _HOST_FOLDER="$_FOLDER/storage/$_HOST_NAME"
      _LOG_FILE="$_FOLDER/logs/$_HOST_NAME.log"

      if [ -e "$_HOST_FILE" ]; then
        case $_RESTORE_TYPE in
          databases)
            restore_database
            ;;
          folders)
            restore_folder
            ;;
        esac
      fi
    fi
  fi
}

select_files () {
  _STORAGE=$_FOLDER/storage/

  for _list in $(ls -R $_STORAGE | grep :)
  do
    _dir=$(echo $_list | cut -d: -f1)

    _file=$(ls -r $_dir/*.gz 2> /dev/null | head -n 1)

    [ -n "$_file" ] && _LIST+="${_file/$_STORAGE/} '' off "
  done

  if [ -z "$_LIST" ]; then
    message "Alert" "Files from restore not found!" && main
  else
    _LIST+="3>&1 1>&2 2>&3"
  fi

  _FILES=$(checklist "Restaurar" "Quais arquivos?" "$_LIST")

  confirm "Do you confirm restore from selected items?"
  [ $? -eq 1 ] && main

  for _file in $_FILES
  do
    select_host $_file
  done

  main
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
