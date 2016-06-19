#!/bin/bash
# https://rvm.io/rvm/install
# https://www.ruby-lang.org/en/downloads
# http://www.cyberciti.biz/faq/linux-logout-user-howto/

_APP_NAME="Ruby"
_DEFAULT_VERSION="2.3.1"
_GROUP="rvm"
_OPTIONS_LIST="install_ruby 'Install Ruby' \
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

install_ruby () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  disable_selinux

  _VERSION=$(input "Ruby version" $_DEFAULT_VERSION)
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && _VERSION=$_DEFAULT_VERSION

  confirm "Do you confirm the installation of Ruby $_VERSION?"
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

setup
main
