#!/bin/bash

export _APP_NAME="Backup"
_FOLDER="/opt/tools/backup"
_OPTIONS_LIST="install_backup 'Install or update backup' \
               config_backup  'Config backup' \
               aws_cli 'Install and config aws client' \
               perform_backup 'Perform backup' \
               view_log_tail 'View log tail' \
               view_crontab 'View crontab file' \
               about 'About Backup'"

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

  curl -sS "$_TEMPLATES/$_SCRIPT" > "$_FOLDER/$_SCRIPT"

  chmod +x "$_FOLDER/$_SCRIPT"

  [ ! -e "backup.conf" ] && wget -q "$_TEMPLATES/backup.conf"
  [ ! -e "hosts.list" ] && wget -q "$_TEMPLATES/hosts.list"

  cd "$_FOLDER/hosts"
  curl -sS "$_TEMPLATES/hosts/example.list" > "$_FOLDER/hosts/example.list"

  _FIND_RECORD=$(grep "$_FOLDER/$_SCRIPT" "$_CRON_USER_FILE")

  if [ -z "$_FIND_RECORD" ]; then
    su -c "echo \"0 23 * * * $_FOLDER/$_SCRIPT\" >> $_CRON_USER_FILE"

    chown "$_USER_LOGGED":"$_USER_LOGGED" "$_CRON_USER_FILE"
  fi

  chown "$_USER_LOGGED":"$_USER_LOGGED" -R "$_FOLDER"

  [ $? -eq 0 ] && message "Notice" "Backup successfully installed in '$_FOLDER'. See about section for more details."
}

view_config () {
  textbox "$_CONFIG_FILE"
}

edit_config () {
  _VARS="_AWS_BUCKET _RSYNC_HOST _MAX_FILES"

  for _VAR in $_VARS
  do
    _OLD_VALUE=$(search_value "$_VAR" "$_CONFIG_FILE")

    _PARAM=$(echo "$_VAR" | tr '[:upper:]' '[:lower:]' | sed 's/_/./g')

    _NEW_VALUE=$(input_field "backup.$_PARAM" "$_VAR" "$_OLD_VALUE")
    [ $? -eq 1 ] && main

    egrep "^$_VAR=" "$_CONFIG_FILE" > /dev/null

    if [ $? -eq 0 ]; then
      change_file replace $_CONFIG_FILE "^$_VAR=$_OLD_VALUE" "$_VAR=$_NEW_VALUE"
    else
      change_file append $_CONFIG_FILE "^#$_VAR=" "$_VAR=$_NEW_VALUE"
    fi
  done
}

config_backup () {
  [ ! -e "$_CONFIG_FILE" ] && message "Alert" "$_CONFIG_FILE not found!"

  _CONFIG_LIST="view_config 'View config file' \
                edit_config 'Edit config file'"

  _CONFIG_OPTION=$(menu "Select the option" "$_CONFIG_LIST")

  if [ -z "$_CONFIG_OPTION" ]; then
    main
  else
    $_CONFIG_OPTION

    config_backup
  fi
}

perform_backup () {
  _BACKUP_SCRIPT="$_FOLDER/backup.sh"

  if [ -e "$_BACKUP_SCRIPT" ]; then
    run_as_user "$_USER_LOGGED" "bash $_BACKUP_SCRIPT"

    [ $? -eq 0 ] && message "Notice" "Backup performed!"
  else
    message "Alert" "Backup not installed!"
  fi
}

view_log_tail () {
  ls $_FOLDER/logs > /dev/null

  [ $? -ne 0 ] && message "Alert" "Backup logs not found!"

  _LOGS=$(ls $_FOLDER/logs/*.log)
  _MENU=""

  for log in $_LOGS
  do
    _MENU+="$log '' "
  done

  _LOG_FILE=$(menu "Select the log file" "$_MENU")

  if [ -z "$_LOG_FILE" ]; then
    main
  else
    tailbox $_LOG_FILE
    view_log_tail
  fi
}

view_crontab () {
  _MESSAGE=$(run_as_user "$_USER_LOGGED" "crontab -l")

  message "crontab -e for edit file" "$_MESSAGE"
}

aws_cli_install () {
  confirm "Do you confirm install aws client?"
  [ $? -eq 1 ] && aws_cli

  $_PACKAGE_COMMAND install -y awscli

  [ $? -eq 0 ] && message "Notice" "aws client successfully installed!" aws_cli
}

aws_credentials_show () {
  if [ -e "$_AWS_CONFIG_FILE" ]; then
    textbox $_AWS_CONFIG_FILE
    aws_cli
  else
    message "Alert" "aws credentials file not found!" aws_cli
  fi
}

aws_credentials_edit () {
  if [ -e "$_AWS_CONFIG_FILE" ]; then
    _aws_access_key_id=$(search_value "aws_access_key_id" "$_AWS_CONFIG_FILE")
    _aws_secret_access_key=$(search_value "aws_secret_access_key" "$_AWS_CONFIG_FILE")
    _aws_region=$(search_value "region" "$_AWS_CONFIG_FILE")
  fi

  _AWS_ACCESS_KEY_ID=$(input_field "backup.aws.access.key.id" "aws access key id" "$_aws_access_key_id")
  [ $? -eq 1 ] && main
  [ -z "$_AWS_ACCESS_KEY_ID" ] && message "Alert" "The aws access key id can not be blank!"

  _AWS_SECRET_ACCESS_KEY=$(input_field "backup.aws.secret.access.key" "aws secret access key" "$_aws_secret_access_key")
  [ $? -eq 1 ] && main
  [ -z "$_AWS_SECRET_ACCESS_KEY" ] && message "Alert" "The aws secret access key can not be blank!"

  _AWS_REGION=$(input_field "backup.aws.region" "aws region" "$_aws_region")
  [ $? -eq 1 ] && main
  [ -z "$_AWS_REGION" ] && message "Alert" "The aws region can not be blank!"

  confirm "Do you confirm aws config edition?"
  [ $? -eq 1 ] && aws_cli

  _AWS_CONFIG_DIR="/home/$_USER_LOGGED/.aws/"

  mkdir -p $_AWS_CONFIG_DIR

  echo "[default]" > $_AWS_CONFIG_FILE
  echo "aws_access_key_id = $_AWS_ACCESS_KEY_ID" >> $_AWS_CONFIG_FILE
  echo "aws_secret_access_key = $_AWS_SECRET_ACCESS_KEY" >> $_AWS_CONFIG_FILE
  echo "region = $_AWS_REGION" >> $_AWS_CONFIG_FILE

  chown $_USER_LOGGED: -R $_AWS_CONFIG_DIR

  aws_credentials_show
}

aws_cli () {
  _AWS_LIST="aws_cli_install 'Install aws client' \
             aws_credentials_show 'Show aws credentials' \
             aws_credentials_edit 'Edit aws credentials'"

  _AWS_OPTION=$(menu "Select the option" "$_AWS_LIST")

  if [ -z "$_AWS_OPTION" ]; then
    main
  else
    $_AWS_OPTION
  fi
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

  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")
  _CONFIG_FILE="$_FOLDER/backup.conf"
  _AWS_CONFIG_FILE="/home/$_USER_LOGGED/.aws/config"
  _CRON_USER_FILE="/var/spool/cron/crontabs/$_USER_LOGGED"

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    if [ -n "$(search_app backup)" ]; then
      install_backup
      edit_config
    fi

    if [ -n "$(search_app backup.aws)" ]; then
      aws_cli_install
      aws_credentials_edit
    fi
  fi
}

setup
main
