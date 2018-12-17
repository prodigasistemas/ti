#!/bin/bash
# For check sintax: bash -n backup.sh
# For debug:
# set -v
# set -x

export _APP_NAME="Main menu"
_OPTIONS_LIST="java 'Java JDK' \
               ruby 'Ruby Interpreter' \
               nginx 'NGINX Web Server' \
               postgresql 'PostgreSQL Database Server' \
               mysql 'MySQL Database Server' \
               docker 'Docker platform' \
               oracledb 'Oracle Database XE' \
               gitlab 'GitLab' \
               jenkins 'Jenkins Automation Server' \
               sonar 'SonarQube Quality' \
               redmine 'Redmine Project Management' \
               archiva 'Archiva' \
               jboss 'JBoss App Server' \
               nagios 'Nagios' \
               gsan 'GSAN' \
               ggas 'GGAS' \
               backup 'Backup' \
               puma 'Puma App Service' \
               sidekiq 'Sidekiq Queue Service'"

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

main () {
  tool_check curl

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_MAIN_OPTION" ]; then
      clear && exit 0
    else
      curl -sS "$_CENTRAL_URL_TOOLS/scripts/install/$_MAIN_OPTION/linux.sh" | bash

      [ $? -ne 0 ] && message "Alert" "Installer not found!"

      main
    fi
  else
    _APPLICATIONS=$(search_applications)
    for app in $_APPLICATIONS; do
      print_colorful yellow bold "> Loading $app installer..."

      curl -sS "$_CENTRAL_URL_TOOLS/scripts/install/$app/linux.sh" | bash
    done
  fi
}

setup
main
