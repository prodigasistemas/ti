#!/bin/bash

# https://docs.docker.com/engine/installation/linux/ubuntulinux/
# https://docs.docker.com/engine/installation/linux/debian/
# https://docs.docker.com/engine/installation/linux/centos/

_GROUP="docker"
_OPTIONS_LIST="install_docker 'Install Docker' \
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

  _TITLE="--backtitle \"Docker installation | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
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

install_docker () {
  dialog --yesno "Confirm the installation of Docker in $_OS_DESCRIPTION?" 0 0
  [ $? -eq 1 ] && main

  case $_OS_TYPE in
    deb)
      if [ $_OS_NAME = "debian" ]; then
        apt-get purge -y lxc-docker* docker.io*

        if [ $_OS_CODENAME = "wheezy" ]; then
          run_as_root "echo \"deb http://http.debian.net/debian wheezy-backports main\" > /etc/apt/sources.list.d/backports.list"
        fi
      fi

      apt-get update
      apt-get install -y apt-transport-https ca-certificates

      apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

      run_as_root "echo \"deb https://apt.dockerproject.org/repo $_OS_NAME-$_OS_CODENAME main\" > /etc/apt/sources.list.d/docker.list"

      apt-get update

      if [ $_OS_NAME = "ubuntu" ]; then
        apt-get purge -y lxc-docker
        apt-get install -y linux-image-extra-$(uname -r)
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

  service docker start

  docker run hello-world

  add_to_group no

  message "Notice" "Docker successfully installed!"
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
      message "Notice" "$_USER user was added the $_GROUP group successfully! You need to log out and log in again"
    else
      message "Error" "A problem has occurred in the operation!"
    fi
  fi
}

main () {
  tool_check dialog

  _MAJOR_VERION=$(uname -r | cut -d. -f1)
  _MINOR_VERION=$(uname -r | cut -d. -f2)

  if [ $_OS_ARCH = "32" ]; then
    dialog --title "Alert" --msgbox "Docker requires a 64-bit installation regardless of your distribution version!" 0 0
    clear && exit 0
  fi

  if [ $_OS_NAME = "debian" ]; then
    if [ $_MAJOR_VERION -lt 3 ]; then
      dialog --title "Alert" --msgbox "Prerequisites Docker: the major version of Kernel ($_OS_KERNEL) is less than 3!" 0 0
      clear && exit 0
    fi

    if [ $_MINOR_VERION -lt 10 ]; then
      dialog --title "Alert" --msgbox "Prerequisites Docker: the minor version of Kernel ($_OS_KERNEL) is less than 10!" 0 0
      clear && exit 0
    fi
  fi

  _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_OPTION" ]; then
    clear && exit 0
  else
    $_OPTION
  fi
}

os_check
main
