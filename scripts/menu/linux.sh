#!/bin/bash

_APP_NAME="Main menu"
_OPTIONS_LIST="java 'Java installer' \
               ruby 'Ruby installer' \
               nginx 'NGINX installer' \
               postgresql 'PostgreSQL installer' \
               mysql 'MySQL installer' \
               docker 'Docker installer' \
               oracledb 'Oracle Database XE installer' \
               gitlab 'GitLab installer' \
               jenkins 'Jenkins CI installer' \
               sonar 'SonarQube installer' \
               redmine 'Redmine installer' \
               archiva 'Archiva installer' \
               jboss 'JBoss installer'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="http://prodigasistemas.github.io"

  ping -c 1 $(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g' | cut -d: -f1) > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

main () {
  tool_check curl
  tool_check dialog

  if [ "$(provisioning)" = "manual" ]; then
    _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_MAIN_OPTION" ]; then
      clear && exit 0
    else
      curl -sS $_CENTRAL_URL_TOOLS/scripts/install/$_MAIN_OPTION/linux.sh | bash

      [ $? -ne 0 ] && message "Alert" "Installer not found!"

      main
    fi
  else
    _APPLICATIONS=$(search_applications)
    for app in $_APPLICATIONS; do
      echo
      echo "> Loading $app installer..."
      echo
      curl -sS $_CENTRAL_URL_TOOLS/scripts/install/$app/linux.sh | bash
    done
  fi
}

setup
main
