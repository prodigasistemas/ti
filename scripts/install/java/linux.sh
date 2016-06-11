#!/bin/bash
# http://www.oracle.com/technetwork/java/javase/downloads/index.html

_PACKAGE_COMMAND_DEBIAN="apt-get"
_PACKAGE_COMMAND_CENTOS="yum"
_DEFAULT_INSTALLATION_FOLDER="/opt"
_ARCH_LIST="i586 '32 bits' x64 '64 bits'"
_VERSION_LIST="openJDK6 'OpenJDK 6' openJDK7 'OpenJDK 7' oracleJava6 'Oracle Java 6 JDK' oracleJava7 'Oracle Java 7 JDK' oracleJava8 'Oracle Java 8 JDK'"

os_check () {
  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_DEBIAN
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _PACKAGE_COMMAND=$_PACKAGE_COMMAND_CENTOS
  fi

  _TITLE="--backtitle \"Java installation - OS: $_OS_NAME\""
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

download_java () {
  wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$1-$2/jdk-$1-linux-$3"
}

delete_file () {
  [ -e "$1" ] && rm $1
}

run_as_root () {
  su -c "$1"
}

install_openJDK6 () {
  if [ $_OS_TYPE = "deb" ]; then
    _PACKAGE_NAME="openjdk-6-jdk"
  elif [ $_OS_TYPE = "rpm" ]; then
    _PACKAGE_NAME="java-1.6.0-openjdk-devel"
  fi

  $_PACKAGE_COMMAND install -y $_PACKAGE_NAME
}

install_openJDK7 () {
  if [ $_OS_TYPE = "deb" ]; then
    _PACKAGE_NAME="openjdk-7-jdk"
  elif [ $_OS_TYPE = "rpm" ]; then
    _PACKAGE_NAME="java-1.7.0-openjdk-devel"
  fi

  $_PACKAGE_COMMAND install -y $_PACKAGE_NAME
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
  _JAVA_VERSION=$(menu "Select the version" "$_VERSION_LIST")

  if [ -z "$_JAVA_VERSION" ]; then
    clear
    exit 0
  else
    _ARCH=$(menu "Select the architecture" "$_ARCH_LIST")
    [ -z "$_ARCH" ] && main

    dialog --yesno "Do you confirm the installation of $_JAVA_VERSION ($_ARCH)?" 0 0
    [ $? = 1 ] && main

    install_$_JAVA_VERSION
  fi
}

os_check
tool_check wget
tool_check dialog
main
