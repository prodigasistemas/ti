#!/bin/bash
# https://rvm.io/rvm/install
# https://www.ruby-lang.org/en/downloads

_DEFAULT_VERSION="2.3.1"
_GROUP="rvm"
_OPTIONS_LIST="install_ruby 'Install Ruby' \
               add_to_group 'Add a user to the group $_GROUP'"

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | awk '{ print tolower($3) }' | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
  fi

  _TITLE="--backtitle \"Ruby installation | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
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

install_ruby () {
  _VERSION=$(input "Ruby version" $_DEFAULT_VERSION)
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && _VERSION=$_DEFAULT_VERSION

  dialog --yesno "Do you confirm the installation of Ruby $_VERSION?" 0 0
  [ $? -eq 1 ] && main

  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

  curl -sSL https://get.rvm.io | bash -s stable

  source /etc/profile.d/rvm.sh

  rvmsudo rvm install $_VERSION

  rvmsudo rvm alias create default $_VERSION

  echo "gem: --no-rdoc --no-ri" | tee /etc/gemrc

  gem install bundler

  message "Notice" "Success! Enter the command: rvm -v. If not found, log out and log back. After, execute: gem install bundler"
}

add_to_group () {
  _USER=$(input "Enter the user name to be added to the group $_GROUP")
  [ $? -eq 1 ] && main
  [ -z "$_USER" ] && message "Alert" "The user name can not be blank!"

  _FIND_USER=$(cat /etc/passwd | grep $_USER)
  [ -z "$_FIND_USER" ] && message "Alert" "User not found!"

  if [ $_OS_NAME = "debian" ]; then
    gpasswd -a $_USER $_GROUP
  else
    usermod -aG $_GROUP $_USER
  fi

  if [ $? -eq 0 ]; then
    message "Notice" "$_USER user was added the $_GROUP group successfully! You need to log out and log in again"
  else
    message "Error" "A problem has occurred in the operation!"
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
