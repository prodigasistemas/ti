#!/bin/bash

_URL_CENTRAL="http://prodigasistemas.github.io"
_OPTIONS_LIST="ruby 'Ruby install' \
               nginx 'NGINX install' \
               postgresql 'PostgreSQL install' \
               mysql 'MySQL install' \
               docker 'Docker install' \
               oracledb 'Oracle Database XE install' \
               gitlab 'GitLab install' \
               jenkins 'Jenkins CI install' \
               sonar 'SonarQube install' \
               redmine 'Redmine install' \
               archiva 'Archiva install' \
               jboss 'JBoss install'"

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

  _TITLE="--backtitle \"Pródiga Sistemas - Tools Installer | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
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

message () {
  eval dialog --title \"$1\" --msgbox \"$2\" 0 0
  main
}

main () {
  tool_check curl
  tool_check dialog

  _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_MAIN_OPTION" ]; then
    clear && exit 0
  else
    curl -sS $_URL_CENTRAL/scripts/install/$_MAIN_OPTION/linux.sh | bash

    [ $? -ne 0 ] && message "Error" "Installation not found!"

    main
  fi
}

os_check
main