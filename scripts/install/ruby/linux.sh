#!/bin/bash
# https://rvm.io/rvm/install
# https://www.ruby-lang.org/en/downloads
# http://www.cyberciti.biz/faq/linux-logout-user-howto/

_DEFAULT_VERSION="2.3.1"
_GROUP="rvm"
_OPTIONS_LIST="install_ruby 'Install Ruby' \
               add_to_group 'Add a user to the group $_GROUP'"

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
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

  if [ -z "$3" ]; then
    main
  else
    $3
  fi
}

run_as_root () {
  su -c "$1"
}

run_as_user () {
  su - $1 -c "$2"
}

disable_selinux () {
  _SELINUX_ENABLED=$(cat /etc/selinux/config | grep "^SELINUX=enforcing")

  if [ ! -z "$_SELINUX_ENABLED" ]; then
    dialog --title "$_SELINUX_ENABLED detected. Is changed to SELINUX=permissive" --msgbox "" 0 0

    change_file "replace" "/etc/selinux/config" "^$_SELINUX_ENABLED" "SELINUX=permissive"
  fi
}

install_ruby () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  [ "$_OS_TYPE" = "rpm" ] && disable_selinux

  _VERSION=$(input "Ruby version" $_DEFAULT_VERSION)
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && _VERSION=$_DEFAULT_VERSION

  dialog --yesno "Do you confirm the installation of Ruby $_VERSION?" 0 0
  [ $? -eq 1 ] && main

  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

  curl -sSL https://get.rvm.io | bash -s stable

  source /etc/profile.d/rvm.sh

  add_to_group no

  case $_OS_TYPE in
    deb)
      rvmsudo rvm install $_VERSION
      rvmsudo rvm alias create default $_VERSION
      ;;
    rpm)
      run_as_user $_USER_LOGGED "rvmsudo rvm install $_VERSION"
      run_as_user $_USER_LOGGED "rvmsudo rvm alias create default $_VERSION"
      ;;
  esac

  run_as_root "echo \"gem: --no-rdoc --no-ri\" > /etc/gemrc"

  run_as_user $_USER_LOGGED "gem install bundler"

  message "Notice" "Success! Will be you logout. After, enter the command: ruby -v" "pkill -KILL -u $_USER_LOGGED"
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
