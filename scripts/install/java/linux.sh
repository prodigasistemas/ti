#!/bin/bash
# http://www.oracle.com/technetwork/java/javase/downloads/index.html
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

_APP_NAME="Java"
_DEFAULT_INSTALLATION_FOLDER="/opt"
_OPTIONS_LIST="openJDK6 'OpenJDK 6' openJDK7 'OpenJDK 7' openJDK8 'OpenJDK 8' oracleJDK6 'Oracle Java 6 JDK' oracleJDK7 'Oracle Java 7 JDK' oracleJDK8 'Oracle Java 8 JDK'"

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

download_java () {
  tool_check wget

  cd $_DEFAULT_INSTALLATION_FOLDER && wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$1-$2/jdk-$1-linux-$3"
}

install_openJDK () {
  _OPENJDK_VERSION=$1
  [ "$_OS_TYPE" = "deb" ] && _PACKAGE_NAME="openjdk-$_OPENJDK_VERSION-jdk"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGE_NAME="java-1.$_OPENJDK_VERSION.0-openjdk-devel"

  $_PACKAGE_COMMAND install -y $_PACKAGE_NAME

  [ $? -eq 0 ] && message "Notice" "Java $_OPENJDK_VERSION successfully installed!"
}

install_openJDK6 () {
  install_openJDK 6
}

install_openJDK7 () {
  install_openJDK 7
}

install_openJDK8 () {
  install_openJDK 8
}

install_oracleJDK6 () {
  _JAVA_VERSION="6u45"
  _BINARY_VERSION="b06"
  _JAVA_FOLDER="jdk1.6.0_45"
  _JAVA_FILE="jdk-$_JAVA_VERSION-linux-$_ARCH.bin"

  download_java $_JAVA_VERSION $_BINARY_VERSION "$_ARCH.bin"

  cd $_DEFAULT_INSTALLATION_FOLDER && bash $_JAVA_FILE

  ln -sf $_DEFAULT_INSTALLATION_FOLDER/$_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/java-oracle-6

  delete_file $_JAVA_FILE

  [ $? -eq 0 ] && message "Notice" "Oracle Java 6 successfully installed in '$_DEFAULT_INSTALLATION_FOLDER/java-oracle-6'!"
}

install_oracleJDK () {
  _JAVA_VERSION=$1
  _JAVA_UPDATE=$2
  _BINARY_VERSION=$3
  _JAVA_FOLDER="jdk1.${_JAVA_VERSION}.0_${_JAVA_UPDATE}"
  _JAVA_PACKAGE="${_JAVA_VERSION}u${_JAVA_UPDATE}"

  if [ "$_OS_TYPE" = "deb" ]; then
    download_java $_JAVA_PACKAGE $_BINARY_VERSION "$_ARCH.tar.gz"

    _JAVA_FILE="jdk-$_JAVA_PACKAGE-linux-$_ARCH.tar.gz"
    _INSTALL_FOLDER="in '$_DEFAULT_INSTALLATION_FOLDER/java-oracle-$_JAVA_VERSION'"

    cd $_DEFAULT_INSTALLATION_FOLDER && tar -xzf $_JAVA_FILE

    ln -sf $_DEFAULT_INSTALLATION_FOLDER/$_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/java-oracle-$_JAVA_VERSION

  elif [ "$_OS_TYPE" = "rpm" ]; then
    download_java $_JAVA_PACKAGE $_BINARY_VERSION "$_ARCH.rpm"

    _JAVA_FILE="jdk-$_JAVA_PACKAGE-linux-$_ARCH.rpm"

    $_PACKAGE_COMMAND localinstall -y $_JAVA_FILE
  fi

  delete_file $_JAVA_FILE

  [ $? -eq 0 ] && message "Notice" "Oracle Java $_JAVA_VERSION successfully installed${_INSTALL_FOLDER}!"
}

install_oracleJDK7 () {
  install_oracleJDK "7" "80" "b15"
}

install_oracleJDK8 () {
  install_oracleJDK "8" "92" "b14"
}

main () {
  [ "$_OS_ARCH" = "32" ] && _ARCH="i586"
  [ "$_OS_ARCH" = "64" ] && _ARCH="x64"

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _JAVA_VERSION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_JAVA_VERSION" ]; then
      clear && exit 0
    else
      confirm "Do you confirm the installation of $_JAVA_VERSION ($_OS_ARCH bits)?"
      [ $? -eq 1 ] && main

      install_$_JAVA_VERSION
    fi
  else
    if [ ! -z "$(search_app java)" ]; then
      _JAVA_VERSIONS=$(search_versions java.version)
      for java_version in $_JAVA_VERSIONS; do
        echo
        print_colorful yellow bold "> Installing $java_version..."
        echo
        install_$java_version
      done
    fi
  fi
}

setup
main
