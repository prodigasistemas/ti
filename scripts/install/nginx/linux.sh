#!/bin/bash
# http://nginx.org/en/linux_packages.html
# http://stackoverflow.com/questions/20988371/linux-bash-get-releasever-and-basearch-values
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

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

  _TITLE="--backtitle \"NGINX installation - OS: $_OS_DESCRIPTION\""
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

message () {
  eval dialog --title \"$1\" --msgbox \"$2\" 0 0
}

run_as_root () {
  su -c "$1"
}

install_nginx () {
  dialog --yesno "Confirm the installation of NGINX in $_OS_DESCRIPTION?" 0 0
  [ $? = 1 ] && clear && exit 0

  if [ $_OS_TYPE = "deb" ]; then
    curl -L http://nginx.org/keys/nginx_signing.key 2> /dev/null | apt-key add - &>/dev/null

    run_as_root "echo \"deb http://nginx.org/packages/$_OS_NAME/ $_OS_CODENAME nginx\" > /etc/apt/sources.list.d/nginx.list"

    $_PACKAGE_COMMAND update
  elif [ $_OS_TYPE = "rpm" ]; then
    _REPO_FILE="/etc/yum.repos.d/nginx.repo"

    run_as_root "echo [nginx] > $_REPO_FILE"
    run_as_root "echo name=nginx repo >> $_REPO_FILE"
    run_as_root "echo baseurl=http://nginx.org/packages/$_OS_NAME/$_OS_RELEASE/$_OS_ARCH/ >> $_REPO_FILE"
    run_as_root "echo gpgcheck=0 >> $_REPO_FILE"
    run_as_root "echo enabled=1 >> $_REPO_FILE"

    curl -L http://nginx.org/keys/nginx_signing.key 2> /dev/null | rpm --import - &>/dev/null
  fi

  $_PACKAGE_COMMAND -y install nginx

  chmod 775 /var/log/nginx

  [ $_OS_TYPE = "rpm" ] && service nginx start

  message "Notice" "NGINX successfully installed!"
  clear
}

main () {
  tool_check curl
  tool_check dialog

  install_nginx
}

os_check
main
