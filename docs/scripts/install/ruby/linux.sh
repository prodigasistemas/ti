#!/bin/bash
# https://rvm.io/rvm/install
# https://www.ruby-lang.org/en/downloads
# http://www.cyberciti.biz/faq/linux-logout-user-howto/

export _APP_NAME="Ruby"
_DEFAULT_VERSION="2.4.2"
_GROUP="rvm"
_OPTIONS_LIST="install_ruby 'Install Ruby' \
               add_to_group 'Add a user to the group $_GROUP'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="https://prodigasistemas.github.io/ti"

  ping -c 1 "$(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g; s|/ti||g;' | cut -d: -f1)" > /dev/null
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

  _VERSION=$(input_field "ruby.version" "Ruby version" "$_DEFAULT_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_VERSION" ] && message "Alert" "The Ruby version can not be blank!"

  confirm "Do you confirm the installation of Ruby $_VERSION?"
  [ $? -eq 1 ] && main

  _GPG_COMMAND="gpg"

  if [ "$_OS_TYPE" = "deb" ]; then
    _OS_VERSION=$(echo "$_OS_NUMBER" | cut -d. -f1)

    [ "$_OS_VERSION" -ge 16 ] && _GPG_COMMAND="gpgv2"
  fi

  $_GPG_COMMAND --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

  curl -sSL https://get.rvm.io | bash -s stable

  source /etc/profile.d/rvm.sh

  add_user_to_group $_GROUP "[no_alert]"

  case $_OS_TYPE in
    deb)
      rvmsudo rvm install "$_VERSION"
      rvmsudo rvm alias create default "$_VERSION"
      ;;
    rpm)
      run_as_user "$_USER_LOGGED" "rvmsudo rvm install $_VERSION"
      run_as_user "$_USER_LOGGED" "rvmsudo rvm alias create default $_VERSION"
      ;;
  esac

  run_as_root "echo \"gem: --no-rdoc --no-ri\" > /etc/gemrc"

  run_as_user "$_USER_LOGGED" "gem install bundler"

  [ $? -eq 0 ] && message "Notice" "Success! Will be you logout or put command: 'source /etc/profile.d/rvm.sh'. After, enter the command: ruby -v"
}

add_to_group () {
  add_user_to_group $_GROUP
}

main () {
  tool_check curl

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app ruby)" ] && install_ruby
  fi
}

setup
main
