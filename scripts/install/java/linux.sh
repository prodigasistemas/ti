#!/bin/bash
# http://www.oracle.com/technetwork/java/javase/downloads/index.html
# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

_APP_NAME="Java"
_DEFAULT_INSTALLATION_FOLDER="/opt"
_OPTIONS_LIST="openJDK6 'OpenJDK 6' openJDK7 'OpenJDK 7' openJDK8 'OpenJDK 8' oracleJava6 'Oracle Java 6 JDK' oracleJava7 'Oracle Java 7 JDK' oracleJava8 'Oracle Java 8 JDK'"

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
  wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$1-$2/jdk-$1-linux-$3"
}

install_openJDK () {
  _OPENJDK_VERSION=$1
  [ $_OS_TYPE = "deb" ] && _PACKAGE_NAME="openjdk-$_OPENJDK_VERSION-jdk"
  [ $_OS_TYPE = "rpm" ] && _PACKAGE_NAME="java-1._OPENJDK_VERSION.0-openjdk-devel"

  $_PACKAGE_COMMAND install -y $_PACKAGE_NAME

  message "Notice" "Java $_OPENJDK_VERSION successfully installed!"
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

install_oracleJava6 () {
  _JAVA_VERSION="6u45"
  _BINARY_VERSION="b06"
  _JAVA_FOLDER="jdk1.6.0_45"
  _JAVA_FILE="jdk-$_JAVA_VERSION-linux-$_ARCH.bin"

  download_java $_JAVA_VERSION $_BINARY_VERSION "$_ARCH.bin"

  bash $_JAVA_FILE
  mv $_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/
  ln -s $_DEFAULT_INSTALLATION_FOLDER/$_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/java-oracle-6

  delete_file $_JAVA_FILE

  message "Notice" "Java successfully installed in '$_DEFAULT_INSTALLATION_FOLDER/java-oracle-6'!"
}

install_oracleJava7 () {
  _JAVA_VERSION="7u80"
  _BINARY_VERSION="b15"
  _JAVA_FOLDER="jdk1.7.0_80"

  if [ $_OS_TYPE = "deb" ]; then
    download_java $_JAVA_VERSION $_BINARY_VERSION "$_ARCH.tar.gz"

    _JAVA_FILE="jdk-$_JAVA_VERSION-linux-$_ARCH.tar.gz"
    _INSTALL_FOLDER="in '$_DEFAULT_INSTALLATION_FOLDER/java-oracle-7'"
    tar -xvzf $_JAVA_FILE
    mv $_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/
    ln -s $_DEFAULT_INSTALLATION_FOLDER/$_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/java-oracle-7

  elif [ $_OS_TYPE = "rpm" ]; then
    download_java $_JAVA_VERSION $_BINARY_VERSION "$_ARCH.rpm"

    _JAVA_FILE="jdk-$_JAVA_VERSION-linux-$_ARCH.rpm"
    $_PACKAGE_COMMAND localinstall -y $_JAVA_FILE
  fi

  delete_file $_JAVA_FILE

  message "Notice" "Java successfully installed $_INSTALL_FOLDER!"
}

install_oracleJava8 () {
  _JAVA_VERSION="8u92"
  _BINARY_VERSION="b14"
  _JAVA_FOLDER="jdk1.8.0_92"

  if [ $_OS_TYPE = "deb" ]; then
    download_java $_JAVA_VERSION $_BINARY_VERSION "$_ARCH.tar.gz"

    _JAVA_FILE="jdk-$_JAVA_VERSION-linux-$_ARCH.tar.gz"
    _INSTALL_FOLDER="in '$_DEFAULT_INSTALLATION_FOLDER/java-oracle-8'"
    tar -xvzf $_JAVA_FILE
    mv $_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER
    ln -s $_DEFAULT_INSTALLATION_FOLDER/$_JAVA_FOLDER $_DEFAULT_INSTALLATION_FOLDER/java-oracle-8

  elif [ $_OS_TYPE = "rpm" ]; then
    download_java $_JAVA_VERSION $_BINARY_VERSION "$_ARCH.rpm"

    _JAVA_FILE="jdk-$_JAVA_VERSION-linux-$_ARCH.rpm"
    $_PACKAGE_COMMAND localinstall -y $_JAVA_FILE
  fi

  delete_file $_JAVA_FILE

  message "Notice" "Java successfully installed $_INSTALL_FOLDER!"
}

main () {
  tool_check wget
  tool_check dialog

  _JAVA_VERSION=$(menu "Select the option" "$_OPTIONS_LIST")

  if [ -z "$_JAVA_VERSION" ]; then
    clear && exit 0
  else
    [ $_OS_ARCH = "32" ] && _ARCH="i586"
    [ $_OS_ARCH = "64" ] && _ARCH="x64"

    confirm "Do you confirm the installation of $_JAVA_VERSION ($_OS_ARCH bits)?"
    [ $? = 1 ] && main

    install_$_JAVA_VERSION
  fi
}

setup
main
