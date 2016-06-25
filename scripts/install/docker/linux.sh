#!/bin/bash

# https://docs.docker.com/engine/installation/linux/ubuntulinux/
# https://docs.docker.com/engine/installation/linux/debian/
# https://docs.docker.com/engine/installation/linux/centos/

_APP_NAME="Docker"
_GROUP="docker"
_OPTIONS_LIST="install_docker 'Install Docker' \
               add_to_group 'Add a user to the group $_GROUP'"

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

install_docker () {
  confirm "Confirm the installation of Docker in $_OS_DESCRIPTION?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      if [ "$_OS_NAME" = "debian" ]; then
        $_PACKAGE_COMMAND purge -y lxc-docker* docker.io*

        if [ $_OS_CODENAME = "wheezy" ]; then
          run_as_root "echo \"deb http://http.debian.net/debian wheezy-backports main\" > /etc/apt/sources.list.d/backports.list"
        fi
      fi

      $_PACKAGE_COMMAND update
      $_PACKAGE_COMMAND install -y apt-transport-https ca-certificates

      apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

      run_as_root "echo \"deb https://apt.dockerproject.org/repo $_OS_NAME-$_OS_CODENAME main\" > /etc/apt/sources.list.d/docker.list"

      $_PACKAGE_COMMAND update

      if [ "$_OS_NAME" = "ubuntu" ]; then
        $_PACKAGE_COMMAND purge -y lxc-docker
        $_PACKAGE_COMMAND install -y linux-image-extra-$_OS_KERNEL
      fi

      apt-cache policy docker-engine
      ;;

    rpm)
      _REPO_FILE="/etc/yum.repos.d/docker.repo"
      run_as_root "echo [dockerrepo] > $_REPO_FILE"
      run_as_root "echo name=Docker Repository >> $_REPO_FILE"
      run_as_root "echo baseurl=https://yum.dockerproject.org/repo/main/$_OS_NAME/$_OS_RELEASE/ >> $_REPO_FILE"
      run_as_root "echo enabled=1 >> $_REPO_FILE"
      run_as_root "echo gpgcheck=1 >> $_REPO_FILE"
      run_as_root "echo gpgkey=https://yum.dockerproject.org/gpg >> $_REPO_FILE"
      ;;

  esac

  $_PACKAGE_COMMAND install -y docker-engine

  admin_service docker start

  docker run hello-world

  add_to_group $_GROUP "[no_alert]"

  message "Notice" "Docker successfully installed!"
}

add_to_group () {
  add_user_to_group $_GROUP
}

main () {
  [ "$(provisioning)" = "manual" ] && tool_check dialog

  _MAJOR_VERSION=$(uname -r | cut -d. -f1)
  _MINOR_VERSION=$(uname -r | cut -d. -f2)

  if [ "$_OS_ARCH" = "32" ]; then
    message "Alert" "Docker requires a 64-bit installation regardless of your distribution version!" "clear && exit 1"
  else
    if [ "$_OS_NAME" = "debian" ]; then
      if [ $_MAJOR_VERSION -lt 3 ]; then
        message "Alert" "Prerequisites Docker: the major version of Kernel ($_OS_KERNEL) is less than 3!" "clear && exit 1"
      fi

      if [ "$_MINOR_VERSION" -lt 10 ]; then
        message "Alert" "Prerequisites Docker: the minor version of Kernel ($_OS_KERNEL) is less than 10!" "clear && exit 1"
      fi
    fi

    if [ "$(provisioning)" = "manual" ]; then
      _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

      if [ -z "$_OPTION" ]; then
        clear && exit 0
      else
        $_OPTION
      fi
    else
      [ ! -z "$(search_app docker)" ] && install_docker
    fi
  fi
}

setup
main
