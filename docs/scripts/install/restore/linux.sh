#!/bin/bash
# set -x

# https://aurelio.net/shell/dialog/#itensescolhidos
# http://xmodulo.com/create-dialog-boxes-interactive-shell-script.html

export _APP_NAME="Restore"
_TOOLS_FOLDER="/opt/tools"
_FOLDER="$_TOOLS_FOLDER/backup"
_STORAGE_FOLDER="$_FOLDER/storage"
_CONFIG_FILE="$_FOLDER/backup.conf"
_LOG_FILE="/tmp/restore.log"
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

msg_log () {
  _MSG=$1

  echo "" >> "$_LOG_FILE"
  echo "$_MSG" >> "$_LOG_FILE"
  echo "" >> "$_LOG_FILE"

  print_colorful yellow bold "$_MSG"
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
      cp "$_STORAGE_FOLDER/$_RESTORE_FILE" "$_destination"

      chown $_USER_LOGGED: "$_destination/$_RESTORE_FILE_NAME"

      [ -e "$_destination/$_RESTORE_FILE_NAME" ] && eval "$_command_line" >> "$_LOG_FILE" 2>> "$_LOG_FILE"
    fi
  else
    _check_command=$(ssh -C -p "$_HOST_PORT" "$_access" "command -v $_command_name")

    if [ -z "$_check_command" ]; then
      message "Error" "$_command_name is not installed!"
    else
      scp -C -P "$_HOST_PORT" "$_STORAGE_FOLDER/$_RESTORE_FILE" "$_access:$_destination" >> "$_LOG_FILE" 2>> "$_LOG_FILE"

      if [ $? -eq 0 ]; then
        ssh -C -p "$_HOST_PORT" "$_access" "$_command_line" >> "$_LOG_FILE" 2>> "$_LOG_FILE"
      fi
    fi
  fi
}

restore_folder () {
  _RESTORE_FOLDER=$(echo $_RESTORE_FILE | cut -d/ -f3)
  _RESTORE_FILE_NAME=$(echo $_RESTORE_FILE | cut -d/ -f4)
  _FOLDER_LIST=$(sed "/^folder:$_RESTORE_FOLDER/ !d;" "$_HOST_FILE")

  if [ -n "$_FOLDER_LIST" ]; then
    _name=$(echo "$_FOLDER_LIST" | cut -d: -f2)
    _path=$(echo "$_FOLDER_LIST" | cut -d: -f3)
    _DEST="/tmp/tools/restore"

    msg_log "> Decompressing $_RESTORE_FILE_NAME to $_HOST_ADDRESS"

    _commands="mkdir -p $_DEST && \
               sudo chown $_USER_LOGGED: -R $_DEST && \
               mv /tmp/$_RESTORE_FILE_NAME $_DEST && \
               cd $_DEST && \
               tar -xzf $_RESTORE_FILE_NAME && \
               sudo rsync -rv $_DEST$_path/ $_path/ ; \
               sudo rm -rf $_DEST"

    perform_restore "tar" "/tmp" "$_commands"
  fi
}

restore_database () {
  _RESTORE_DB_TYPE=$(echo $_RESTORE_FILE | cut -d/ -f3)
  _RESTORE_DB_NAME=$(echo $_RESTORE_FILE | cut -d/ -f4)
  _RESTORE_FILE_NAME=$(echo $_RESTORE_FILE | cut -d/ -f5)
  _DB_FIELDS=$(sed "/^database:$_RESTORE_DB_TYPE/ !d; /$_RESTORE_DB_NAME/ !d;" "$_HOST_FILE")

  if [ -n "$_DB_FIELDS" ]; then
    _DB_TYPE=$(echo "$_DB_FIELDS" | cut -d: -f2)
    _DB_HOST=$(echo "$_DB_FIELDS" | cut -d: -f3)
    _DB_USER=$(echo "$_DB_FIELDS" | cut -d: -f4)
    _DB_PASS=$(echo "$_DB_FIELDS" | cut -d: -f5)

    _SQL_FILE="${_RESTORE_FILE_NAME/.gz/}"

    case $_DB_TYPE in
      mysql)
        _COMMAND=mysql
        _CREATE_1="MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER -e \"CREATE DATABASE $_RESTORE_DB_NAME;\""
        _CREATE_2="MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER -e \"CREATE USER '$_RESTORE_DB_NAME'@'$_DB_HOST' IDENTIFIED BY '$_RESTORE_DB_NAME';\" && \
                   MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER -e \"GRANT ALL PRIVILEGES ON $_RESTORE_DB_NAME.* TO '$_RESTORE_DB_NAME'@'$_DB_HOST' WITH GRANT OPTION;\" && \
                   MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER -e \"FLUSH PRIVILEGES;\""
        _DB_RESTORE="MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER $_RESTORE_DB_NAME"
        ;;

      postgresql)
        _COMMAND=psql
        _CREATE_1="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -c \"CREATE ROLE $_RESTORE_DB_NAME LOGIN ENCRYPTED PASSWORD '$_RESTORE_DB_NAME' NOINHERIT VALID UNTIL 'infinity';\""
        _CREATE_2="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -c \"CREATE DATABASE $_RESTORE_DB_NAME WITH OWNER=$_RESTORE_DB_NAME ENCODING='UTF8';\""
        _DB_RESTORE="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -d $_RESTORE_DB_NAME"
        ;;
    esac

    msg_log "> Restoring $_DB_TYPE database $_RESTORE_DB_NAME to $_HOST_ADDRESS"

    _commands="gunzip /tmp/$_RESTORE_FILE_NAME && \
               $_CREATE_1 && \
               $_CREATE_2 && \
               $_DB_RESTORE < /tmp/$_SQL_FILE ; \
               rm /tmp/$_SQL_FILE"

    perform_restore "$_COMMAND" "/tmp" "$_commands"
  fi
}

select_host () {
  _RESTORE_FILE=$1
  _RESTORE_HOST=$(echo $_RESTORE_FILE | cut -d/ -f1)
  _RESTORE_TYPE=$(echo $_RESTORE_FILE | cut -d/ -f2)

  _HOSTS_LIST="$_FOLDER/hosts.list"

  if [ -e "$_HOSTS_LIST" ]; then
    _HOST_FIELDS=$(egrep "^$_RESTORE_HOST" "$_HOSTS_LIST")

    if [ -n "$_HOST_FIELDS" ]; then
      _HOST_NAME=$(echo "$_HOST_FIELDS" | cut -d: -f1)
      _HOST_ADDRESS=$(echo "$_HOST_FIELDS" | cut -d: -f2)
      _HOST_PORT=$(echo "$_HOST_FIELDS" | cut -d: -f3)
      _HOST_USER=$(echo "$_HOST_FIELDS" | cut -d: -f4)

      _HOST_FILE="$_FOLDER/hosts/$_HOST_NAME.list"
      _HOST_FOLDER="$_FOLDER/storage/$_HOST_NAME"

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
  _LIST=""

  for _list in $(ls -R $_STORAGE_FOLDER | grep :)
  do
    _dir=$(echo $_list | cut -d: -f1)

    _file=$(ls -r $_dir/*.gz 2> /dev/null | head -n 1)

    [ -n "$_file" ] && _LIST+="${_file/$_STORAGE_FOLDER\//} '' off "
  done

  if [ -z "$_LIST" ]; then
    message "Alert" "Files from restore not found!" && main
  else
    _LIST+="3>&1 1>&2 2>&3"
  fi

  _FILES=$(checklist "Restore" "What files?" "$_LIST")

  [ -z "$_FILES" ] && main

  confirm "Do you confirm restore from selected items?"
  [ $? -eq 1 ] && main

  [ -e "$_LOG_FILE" ] && rm "$_LOG_FILE"

  msg_log "[$(date +"%Y-%m-%d %H:%M:%S")] Start restore"

  for _file in $_FILES
  do
    select_host $_file
  done

  if [ -e "$_LOG_FILE" ]; then
    _RESTORE_LOG="$_FOLDER/logs/restore.log"

    cat "$_LOG_FILE" >> $_RESTORE_LOG
    chown $_USER_LOGGED: $_RESTORE_LOG
  fi

  textbox $_LOG_FILE

  [ -e "$_LOG_FILE" ] && rm "$_LOG_FILE"

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
