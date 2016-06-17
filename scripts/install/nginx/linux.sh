#!/bin/bash
# http://nginx.org/en/linux_packages.html
# http://stackoverflow.com/questions/20988371/linux-bash-get-releasever-and-basearch-values
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

_GROUP="nginx"
_OPTIONS_LIST="install_nginx 'Install NGINX' \
               add_to_group 'Add a user to the group $_GROUP'"

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -is | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
  fi

  _TITLE="--backtitle \"NGINX installation | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
}

tool_check() {
  echo "Checking for $1..."
  if command -v $1 > /dev/null; then
    echo "Detected $1..."
  else
    echo "Installing $1..."
    $_PACKAGE_COMMAND install -y $1
  fi
}

menu () {
  echo $(eval dialog $_TITLE --stdout --menu \"$1\" 0 0 0 $2)
}

input () {
  echo $(eval dialog $_TITLE --stdout --inputbox \"$1\" 0 0 \"$2\")
}

message () {
  eval dialog --title \"$1\" --msgbox \"$2\" 0 0
  main
}

run_as_root () {
  su -c "$1"
}

install_nginx () {
  dialog --yesno "Confirm the installation of NGINX in $_OS_DESCRIPTION?" 0 0
  [ $? = 1 ] && main

  if [ $_OS_TYPE = "deb" ]; then
    curl -L http://nginx.org/keys/nginx_signing.key 2> /dev/null | apt-key add - &>/dev/null

    run_as_root "echo \"deb http://nginx.org/packages/$_OS_NAME/ $_OS_CODENAME nginx\" > /etc/apt/sources.list.d/nginx.list"

    $_PACKAGE_COMMAND update
  elif [ $_OS_TYPE = "rpm" ]; then
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

  [ "$_OS_TYPE" = "rpm" ] && service nginx start

  add_to_group no

  message "Notice" "NGINX successfully installed!"
}

add_to_group () {
  _SHOW_ALERT=$1
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  _USER=$(input "Enter the user name to be added to the group $_GROUP" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_USER" ] && message "Alert" "The user name can not be blank!"

  _FIND_USER=$(cat /etc/passwd | grep $_USER)
  [ -z "$_FIND_USER" ] && message "Alert" "User not found!"

  if [ $_OS_NAME = "debian" ]; then
    gpasswd -a $_USER $_GROUP
  else
    usermod -aG $_GROUP $_USER
  fi

  if [ "$_SHOW_ALERT" != "no" ]; then
    if [ $? -eq 0 ]; then
      message "Notice" "$_USER user was added the $_GROUP group successfully!"
    else
      message "Error" "A problem has occurred in the operation!"
    fi
  fi
}

main () {
  tool_check curl
  tool_check dialog

  _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_OPTION" ]; then
    clear && exit 0
  else
    $_OPTION
  fi
}

os_check
main
