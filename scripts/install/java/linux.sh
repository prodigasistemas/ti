#!/bin/bash
# http://www.oracle.com/technetwork/java/javase/downloads/index.html

_PACKAGE_COMMAND_DEBIAN="apt-get"
_PACKAGE_COMMAND_CENTOS="yum"
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

wget_check () {
  echo "Checking for wget..."
  if command -v wget > /dev/null; then
    echo "Detected wget..."
  else
    echo "Installing wget..."
    $_PACKAGE_COMMAND install -q -y wget
  fi
}

dialog_check () {
  echo "Checking for dialog..."
  if command -v dialog > /dev/null; then
    echo "Detected dialog..."
  else
    echo "Installing dialog..."
    $_PACKAGE_COMMAND install -q -y dialog
  fi
}

menu () {
  echo $(eval dialog $_TITLE --stdout --menu \"$1\" 0 0 0 $2)
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
    wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$_JAVA_VERSION-$_BINARY_VERSION/jdk-$_JAVA_VERSION-linux-$_ARCH.bin"
    bash "jdk-$_JAVA_VERSION-linux-$_ARCH.bin"
    mv "$_JAVA_FOLDER" /usr/lib/jvm/
    chown -R root:root "/usr/lib/jvm/$_JAVA_FOLDER"
    ln -s "/usr/lib/jvm/$_JAVA_FOLDER" "/usr/lib/jvm/java-oracle-6"
}

install_oracleJava7 () {
  _JAVA_VERSION="7u80"
  _BINARY_VERSION="b15"
  _JAVA_FOLDER="jdk1.7.0_80"

  if [ $_OS_TYPE = "deb" ]; then
    wget --no-cookies --no-check-certificate --header "Cookie:oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$_JAVA_VERSION-$_BINARY_VERSION/jdk-$_JAVA_VERSION-linux-$_ARCH.tar.gz"
    tar -xvzf "jdk-$_JAVA_VERSION-linux-$_ARCH.tar.gz"
    mv "$_JAVA_FOLDER/" /usr/lib/jvm/
    chown -R root:root "/usr/lib/jvm/$_JAVA_FOLDER"
    ln -s "/usr/lib/jvm/$_JAVA_FOLDER" "/usr/lib/jvm/java-oracle-7"
  elif [ $_OS_TYPE = "rpm" ]; then
    wget --no-cookies --no-check-certificate --header "Cookie:oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$_JAVA_VERSION-$_BINARY_VERSION/jdk-$_JAVA_VERSION-linux-$_ARCH.rpm"
    $_PACKAGE_COMMAND localinstall -y "jdk-$_JAVA_VERSION-linux-$_ARCH.rpm"
  fi
}

install_oracleJava8 () {
  _JAVA_VERSION="8u92"
  _BINARY_VERSION="b14"
  _JAVA_FOLDER="jdk1.8.0_92"

  if [ $_OS_TYPE = "deb" ]; then
    wget --no-cookies --no-check-certificate --header "Cookie:oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$_JAVA_VERSION-$_BINARY_VERSION/jdk-$_JAVA_VERSION-linux-$_ARCH.tar.gz"
    tar -xvzf "jdk-$_JAVA_VERSION-linux-$_ARCH.tar.gz"
    mv "$_JAVA_FOLDER/" /usr/lib/jvm
    chown -R root:root "/usr/lib/jvm/$_JAVA_FOLDER"
    ln -s "/usr/lib/jvm/$_JAVA_FOLDER" "/usr/lib/jvm/java-oracle-8"
  elif [ $_OS_TYPE = "rpm" ]; then
    wget --no-cookies --no-check-certificate --header "Cookie:oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/$_JAVA_VERSION-$_BINARY_VERSION/jdk-$_JAVA_VERSION-linux-$_ARCH.rpm"
    $_PACKAGE_COMMAND localinstall -y "jdk-$_JAVA_VERSION-linux-$_ARCH.rpm"
  fi
}

main () {
  os_check
  wget_check
  dialog_check

  _ARCH=$(menu "Select the architecture" "$_ARCH_LIST")

  [ -z "$_ARCH" ] && main

  _VERSION=$(menu "Select the version" "$_VERSION_LIST")

  [ ! -z "$_ARCH" ] && install_$_VERSION
}

main
