#!/bin/bash
# For check sintax: bash -n backup.sh
# For debug:
# set -v
# set -x

_FOLDER="/opt/tools/backup"

backup_database () {
  _DB_LIST=$(sed '/^ *$/d; /^ *#/d; /^database/!d' "$_HOST_FILE")

  if [ -n "$_DB_LIST" ]; then
    for _database in $_DB_LIST; do
      _DB_TYPE=$(echo "$_database" | cut -d: -f2)
      _DB_HOST=$(echo "$_database" | cut -d: -f3)
      _DB_USER=$(echo "$_database" | cut -d: -f4)
      _DB_PASS=$(echo "$_database" | cut -d: -f5)
      _DATABASE_NAMES=$(echo "$_database" | cut -d: -f6)
      _DATABASE_NAMES=${_DATABASE_NAMES//,/ }

      for _DB_NAME in $_DATABASE_NAMES; do
        _SQL_FILE="$(date +"%Y%m%d-%H%M%S")-$_DB_NAME.sql"
        _BACKUP_FILE="$_SQL_FILE.gz"
        _DEST="$_HOST_FOLDER/databases/$_DB_TYPE/$_DB_NAME"

        make_dir "$_DEST"

        case $_DB_TYPE in
          mysql)
            _COMMAND=mysqldump
            _DB_DUMP="MYSQL_PWD=$_DB_PASS $_COMMAND -h $_DB_HOST -u $_DB_USER $_DB_NAME"
            ;;

          postgresql)
            _COMMAND=pg_dump
            _DB_DUMP="PGPASSWORD=$_DB_PASS $_COMMAND -h $_DB_HOST -U $_DB_USER -d $_DB_NAME"
            ;;
        esac

        write_log "Dumping $_DB_TYPE database $_DB_NAME from $_HOST_ADDRESS"

        perform_backup "$_COMMAND" "$_DEST" "$_DB_DUMP > /tmp/$_SQL_FILE && gzip -9 /tmp/$_SQL_FILE"
      done
    done
  fi
}

backup_folder () {
  _FOLDER_LIST=$(sed '/^ *$/d; /^ *#/d; /^folder/!d' "$_HOST_FILE")

  if [ -n "$_FOLDER_LIST" ]; then
    for _folder in $_FOLDER_LIST; do
      _name=$(echo "$_folder" | cut -d: -f2)
      _path=$(echo "$_folder" | cut -d: -f3)
      _exclude=$(echo "$_folder" | cut -d: -f4)

      [ -n "$_exclude" ] && _exclude=${_exclude//,/ }

      _BACKUP_FILE="$(date +"%Y%m%d-%H%M%S")-$_name.tar.gz"
      _DEST="$_HOST_FOLDER/folders/$_name"

      make_dir "$_DEST"

      if [ -z "$_exclude" ]; then
        _EXCLUDE_FILE=""
        _EXCLUDE_FROM=""
      else
        _EXCLUDE_FILE="/tmp/.backup-folder-$_name.exclude"

        [ -e "$_EXCLUDE_FILE" ] && rm -f "$_EXCLUDE_FILE"

        for _pattern in $_exclude; do
          echo "$_pattern" >> "$_EXCLUDE_FILE"
        done

        _EXCLUDE_FROM="--exclude-from $_EXCLUDE_FILE"
      fi

      write_log "Compressing $_BACKUP_FILE from $_HOST_ADDRESS"

      perform_backup "tar" "$_DEST" "sudo tar --exclude-vcs $_EXCLUDE_FROM -czf /tmp/$_BACKUP_FILE -P $_path" "$_EXCLUDE_FILE"
    done
  fi
}

perform_backup () {
  _command_name=$1
  _destination=$2
  _command_line=$3
  _exclude_file=$4
  _access="$_HOST_USER@$_HOST_ADDRESS"

  if [ "$_HOST_ADDRESS" = "local" ]; then
    if [ -z "$(command -v "$_command_name")" ]; then
      write_log "$_command_name is not installed!"
    else
      eval "$_command_line" >> "$_LOG_FILE" 2>> "$_LOG_FILE"

      if [ $? -eq 0 ] && [ -e "/tmp/$_BACKUP_FILE" ]; then
        sudo chown $USER: "/tmp/$_BACKUP_FILE"
        mv "/tmp/$_BACKUP_FILE" "$_destination"
      fi
    fi

    [ -e "$_exclude_file" ] && rm -f "$_exclude_file"
  else
    _check_command=$(ssh -C -p "$_HOST_PORT" "$_access" "command -v $_command_name")

    if [ -z "$_check_command" ]; then
      write_log "$_command_name is not installed!"
    else
      if [ -e "$_exclude_file" ]; then
        scp -C -P "$_HOST_PORT" "$_exclude_file" "$_access:/tmp/" >> "$_LOG_FILE" 2>> "$_LOG_FILE"
        rm -f "$_exclude_file"
      fi

      ssh -C -p "$_HOST_PORT" "$_access" "$_command_line" >> "$_LOG_FILE" 2>> "$_LOG_FILE"

      if [ $? -eq 0 ]; then
        scp -C -P "$_HOST_PORT" "$_access:/tmp/$_BACKUP_FILE" "$_destination" >> "$_LOG_FILE" 2>> "$_LOG_FILE"

        ssh -C -p "$_HOST_PORT" "$_access" "sudo rm /tmp/$_BACKUP_FILE $_exclude_file" >> "$_LOG_FILE" 2>> "$_LOG_FILE"
      fi
    fi
  fi

  remove_old_files "$_destination"
}

remove_old_files () {
  _DIR=$1

  [ -z "$_MAX_FILES" ] && _MAX_FILES=7

  cd "$_DIR"

  _NUMBER_FILES=$(ls 2> /dev/null | wc -l)

  if [ "$_NUMBER_FILES" -gt "$_MAX_FILES" ]; then
    let _NUMBER_REMOVALS=$_NUMBER_FILES-$_MAX_FILES

    _FILES_REMOVE=$(ls | head -n "$_NUMBER_REMOVALS")

    for _FILE in $_FILES_REMOVE; do
      write_log "Removing old file $_FILE"
      rm -f "$_FILE"
    done
  fi
}

to_sync () {
  _LOG_SYNC="$_FOLDER/logs/synchronizing.log"

  [ -n "$_RSYNC_HOST" ] || [ -n "$_AWS_BUCKET" ] && compact_logs

  if [ -n "$_RSYNC_HOST" ]; then
    if [ -z "$(command -v rsync)" ]; then
      write_sync_log "rsync is not installed!"
    else
      write_head_sync "$_FOLDER with $_RSYNC_HOST"

      rsync -CzpOur --delete --exclude="*.log" --log-file="$_LOG_SYNC" "$_FOLDER" "$_RSYNC_HOST" >> /dev/null 2>> "$_LOG_SYNC"
    fi
  fi

  if [ -n "$_AWS_BUCKET" ]; then
    if [ -z "$(command -v aws)" ]; then
      write_sync_log "awscli is not installed!"
    else
      write_head_sync "$_FOLDER with s3://$_AWS_BUCKET/"

      aws s3 ls "s3://$_AWS_BUCKET" > /dev/null

      if [ $? -ne 0 ]; then
        aws s3 mb "s3://$_AWS_BUCKET"
      fi

      aws s3 sync $_FOLDER "s3://$_AWS_BUCKET/" --delete --exclude="$_FOLDER/logs/*.log" >> "$_LOG_SYNC" 2>> "$_LOG_SYNC"
    fi
  fi
}

write_head_sync () {
  write_sync_log "Synchronizing $1"
}

compact_logs () {
  tar czf "$_FOLDER/logs/logs.tar.gz" -P "$_FOLDER/logs" --exclude="$_FOLDER/logs/*.gz"
}

write_log () {
  _MESSAGE=$1
  _OUTPUT="[$(date +"%Y-%m-%d %H:%M:%S")] $_MESSAGE"

  echo $_OUTPUT
  echo $_OUTPUT >> "$_LOG_FILE"
}

write_sync_log () {
  _MESSAGE=$1
  _OUTPUT="[$(date +"%Y/%m/%d %H:%M:%S")] $_MESSAGE"

  echo $_OUTPUT
  echo $_OUTPUT >> "$_LOG_SYNC"
}

make_dir () {
  _dir=$1
  [ ! -e "$_dir" ] && mkdir -p "$_dir"
}

main () {
  [ -e "$_FOLDER/backup.conf" ] && source "$_FOLDER/backup.conf"

  _HOSTS_FILE="$_FOLDER/hosts.list"

  make_dir "$_FOLDER/logs"

  if [ -e "$_HOSTS_FILE" ]; then
    _HOSTS_LIST=$(sed '/^ *$/d; /^ *#/d;' $_HOSTS_FILE)

    if [ -n "$_HOSTS_LIST" ]; then
      for _host in $_HOSTS_LIST; do
        _HOST_NAME=$(echo "$_host" | cut -d: -f1)
        _HOST_ADDRESS=$(echo "$_host" | cut -d: -f2)
        _HOST_PORT=$(echo "$_host" | cut -d: -f3)
        _HOST_USER=$(echo "$_host" | cut -d: -f4)
        _HOST_FILE="$_FOLDER/hosts/$_HOST_NAME.list"
        _HOST_FOLDER="$_FOLDER/storage/$_HOST_NAME"
        _LOG_FILE="$_FOLDER/logs/$_HOST_NAME.log"

        if [ -e "$_HOST_FILE" ]; then
          backup_database

          backup_folder
        fi
      done
    fi

    to_sync
  else
    write_log "$_HOSTS_FILE is not found!"
  fi
}

main
