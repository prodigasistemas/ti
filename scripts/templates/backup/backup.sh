#!/bin/bash

_FOLDER="/var/tools-backup"

write_log () {
  _MESSAGE=$1
  _HOST_NAME=$2
  _LOG_FILE="$_FOLDER/logs/$_HOST_NAME.log"

  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $_MESSAGE" >> "$_LOG_FILE"
}

backup_database () {
  _HOST_NAME=$1
  _HOST_ADDRESS=$2
  _HOST_PORT=$3
  _HOST_USER=$4
  _HOST_FILE="$_HOST_NAME.conf"
  _HOST_FOLDER="$_FOLDER/data/$_HOST_NAME"
  _LOG_FILE="$_FOLDER/logs/$_HOST_NAME.log"
  _DB_LIST=$(sed '/^ *$/d; /^ *#/d; /^database/!d' "$_HOST_FILE")
  _DB_TYPE_LIST=$(sed '/^ *$/d; /^ *#/d; /^database/!d' "$_HOST_FILE" | cut -d: -f2 | uniq)

  if [ -n "$_DB_LIST" ]; then
    for _DB_TYPE in $_DB_TYPE_LIST; do
      [ ! -e "$_FOLDER/$_DIR" ] && mkdir -p "$_HOST_FOLDER/$_DB_TYPE"
    done

    for _database in $_DB_LIST; do
      _DB_TYPE=$(echo "$_database" | cut -d: -f2)
      _DB_USER=$(echo "$_database" | cut -d: -f3)
      _DB_PASS=$(echo "$_database" | cut -d: -f4)
      _DB_NAMES=$(echo "$_database" | cut -d: -f5)

      for _DB_NAME in $_DB_NAMES; do
        _BACKUP_FILE="$_DB_NAME-$(date +"%Y-%m-%d_%H-%M").sql.gz"

        write_log "Dumping $_BACKUP_FILE"

        cd "$_HOST_FOLDER/$_DB_TYPE"

        case $_DB_TYPE in
          mysql)
            _DB_DUMP="MYSQL_PWD=$_DB_PASS mysqldump -u $_DB_USER $_DB_NAME"
            ;;

          postgresql)
            _DB_DUMP="PGPASSWORD=$_DB_PASS pg_dump -U $_DB_USER -d $_DB_NAME"
            ;;
        esac

        ssh -C -E "$_LOG_FILE" -p "$_HOST_PORT" "$_HOST_USER@$_HOST_ADDRESS" "$_DB_DUMP | gzip -9 > /tmp/$_BACKUP_FILE"

        if [ $? -eq 0 ]; then
          scp -C -P "$_HOST_PORT" "$_HOST_USER@$_HOST_ADDRESS:/tmp/$_BACKUP_FILE" . 2>> "$_LOG_FILE"

          ssh -C -E "$_LOG_FILE" -p "$_HOST_PORT" "$_HOST_USER@$_HOST_ADDRESS" "rm /tmp/$_BACKUP_FILE"
        fi

        if [ -e "$_BACKUP_FILE" ]; then
          [ -z "$_MAX_FILES" ] && _MAX_FILES=7

          _NUMBER_FILES=$(find "$_DB_NAME"*.gz 2> /dev/null | wc -l)

          if [ "$_NUMBER_FILES" -gt "$_MAX_FILES" ]; then
            let _NUMBER_REMOVALS=$_NUMBER_FILES-$_MAX_FILES

            _FILES_REMOVE=$(find "$_DB_NAME"*.gz | head -n "$_NUMBER_REMOVALS")

            for _FILE in $_FILES_REMOVE; do
              write_log "Removing $_FILE"
              rm -f "$_FILE"
            done
          fi
        fi
      done
    done
  fi
}

to_sync () {
  if [ -n "$_RSYNC_HOST" ]; then
    write_log "Synchronizing $_FOLDER with $_RSYNC_HOST"

    rsync -CvzpOur --delete --log-file="$_LOG_FILE" $_FOLDER "$_RSYNC_HOST"
  fi

  if [ -n "$_AWS_BUCKET" ]; then
    if [ -z "$(command -v aws)" ]; then
      write_log "awscli is not installed!"
      exit 1
    fi

    write_log "Synchronizing $_FOLDER with s3://$_AWS_BUCKET/"

    aws s3 sync $_FOLDER "s3://$_AWS_BUCKET/" --delete >> "$_LOG_FILE" 2>> "$_LOG_FILE"
  fi
}

main () {
  [ -e "$_FOLDER/backup.conf" ] && source "$_FOLDER/backup.conf"

  _HOSTS_FILE="$_FOLDER/hosts.list"

  [ ! -e "$_FOLDER/logs" ] && mkdir -p "$_FOLDER/logs"

  if [ ! -e "$_HOSTS_FILE" ]; then
    _HOSTS_LIST=$(sed '/^ *$/d; /^ *#/d;' $_HOSTS_FILE)

    if [ -n "$_HOSTS_LIST" ]; then
      for _host in $_HOSTS_LIST; do
        _hostname=$(echo "$_host" | cut -d: -f1)
        _hostaddress=$(echo "$_host" | cut -d: -f2)
        _hostport=$(echo "$_host" | cut -d: -f3)
        _hostuser=$(echo "$_host" | cut -d: -f4)

        backup_database "$_hostname" "$_hostaddress" "$_hostport" "$_hostuser"
      done
    fi

    to_sync
  fi
}

main