#!/bin/bash
# http://nginx.org/en/linux_packages.html
# http://stackoverflow.com/questions/20988371/linux-bash-get-releasever-and-basearch-values
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

export _APP_NAME="NGINX"
_GROUP="nginx"
_OPTIONS_LIST="install_nginx 'Install NGINX' \
               add_to_group 'Add a user to the group $_GROUP'"

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

install_nginx () {
  confirm "Confirm the installation of NGINX in $_OS_DESCRIPTION?"
  [ $? -eq 1 ] && main

  if [ "$_OS_TYPE" = "deb" ]; then
    wget -q -O - http://nginx.org/keys/nginx_signing.key | sudo apt-key add -

    run_as_root "echo \"deb http://nginx.org/packages/$_OS_NAME/ $_OS_CODENAME nginx\" > /etc/apt/sources.list.d/nginx.list"

    $_PACKAGE_COMMAND update
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _REPO_FILE="/etc/yum.repos.d/nginx.repo"

    [ "$_OS_ARCH" = "32" ] && _NGINX_ARCH="i386"
    [ "$_OS_ARCH" = "64" ] && _NGINX_ARCH="x86_64"

    run_as_root "echo [nginx] > $_REPO_FILE"
    run_as_root "echo name=nginx repo >> $_REPO_FILE"
    run_as_root "echo baseurl=http://nginx.org/packages/$_OS_NAME/$_OS_RELEASE/$_NGINX_ARCH/ >> $_REPO_FILE"
    run_as_root "echo gpgcheck=0 >> $_REPO_FILE"
    run_as_root "echo enabled=1 >> $_REPO_FILE"

    rpm --import http://nginx.org/keys/nginx_signing.key
  fi

  $_PACKAGE_COMMAND -y install nginx

  chmod 775 /var/log/nginx

  admin_service nginx start

  add_user_to_group $_GROUP "[no_alert]"

  message "Notice" "NGINX successfully installed!"
}

add_to_group () {
  add_user_to_group $_GROUP
}

main () {
  tool_check curl
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
    [ -n "$(search_app nginx)" ] && install_nginx
  fi
}

setup
main
