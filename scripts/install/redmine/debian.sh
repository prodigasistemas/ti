#!/bin/bash
# https://rvm.io/rvm/install
# https://www.ruby-lang.org/en/downloads

_DEFAULT_USER=$USER
_DEFAULT_VERSION=2.3.1
_TITLE="--backtitle \"Ruby installation\""

curl_check() {
  echo "Checking for curl..."
  if command -v curl > /dev/null; then
    echo "Detected curl..."
  else
    echo "Installing curl..."
    apt-get install -q -y curl
  fi
}

dialog_check ()
{
  echo "Checking for dialog..."
  if command -v dialog > /dev/null; then
    echo "Detected dialog..."
  else
    echo "Installing dialog..."
    apt-get install -q -y dialog
  fi
}

input () {
  echo $(eval dialog $_TITLE --stdout --inputbox \"$1\" 0 0 \"$2\")
}

params_check() {
  _VERSION=$(input "Ruby version" $_DEFAULT_VERSION)
  [ -z "$_VERSION" ] && _VERSION=$_DEFAULT_VERSION

  _USER=$(input "User to be added to the group rvm" $_DEFAULT_USER)
  [ -z "$_USER" ] && _USER=$_DEFAULT_USER
}

main() {
  curl_check
  dialog_check
  params_check

  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3

  curl -sSL https://get.rvm.io | bash -s stable

  source /etc/profile.d/rvm.sh

  usermod -a -G rvm $_USER

  rvmsudo rvm install $_VERSION

  rvmsudo rvm alias create default $_VERSION

  echo "gem: --no-rdoc --no-ri" | tee /etc/gemrc
  echo
  echo "Done!"
}

main
