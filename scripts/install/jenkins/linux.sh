#!/bin/bash

# https://wiki.jenkins-ci.org/display/JENKINS/Installing+Jenkins+on+Ubuntu
# https://wiki.jenkins-ci.org/display/JENKINS/Installing+Jenkins+on+Red+Hat+distributions

_URL_CENTRAL="http://prodigasistemas.github.io"
_OPTIONS_LIST="install_jenkins 'Install Jenkins' \
               configure_nginx 'Configure host on NGINX'"

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

  _TITLE="--backtitle \"Jenkins installation | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""
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

change_file () {
  _CF_BACKUP=".backup-`date +"%Y%m%d%H%M%S%N"`"
  _CF_OPERATION=$1
  _CF_FILE=$2
  _CF_FROM=$3
  _CF_TO=$4

  case $_CF_OPERATION in
    replace)
      sed -i$_CF_BACKUP -e "s|$_CF_FROM|$_CF_TO|g" $_CF_FILE
      ;;
    append)
      sed -i$_CF_BACKUP -e "/$_CF_FROM/ a $_CF_TO" $_CF_FILE
      ;;
  esac
}

run_as_root () {
  su -c "$1"
}

run_as_user () {
  su - $1 -c "$2"
}

java_check () {
  _VERSION_CHECK=$1

  _JAVA_INSTALLED=$(command -v java)
  [ -z "$_JAVA_INSTALLED" ] && message "Alert" "Java is not installed!"

  java -version 2> /tmp/.java_version
  _JAVA_VERSION=$(cat /tmp/.java_version | grep "java version" | cut -d' ' -f3 | cut -d\" -f2)
  _JAVA_MAJOR_VERSION=$(echo $_JAVA_VERSION | cut -d. -f1)
  _JAVA_MINOR_VERSION=$(echo $_JAVA_VERSION | cut -d. -f2)

  if [ "$_JAVA_MINOR_VERSION" -lt "$_VERSION_CHECK" ]; then
    message "Alert" "You must have Java $_VERSION_CHECK installed!"
  fi
}

install_jenkins () {
  java_check 7

  _HTTP_PORT=$(input "Enter the http port for Jenkins" "8085")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  dialog --yesno "Do you want to download the stable repository?" 0 0
  [ $? -eq 0 ] && _STABLE="-stable"

  dialog --yesno "Do you confirm the installation of Jenkins$_STABLE?" 0 0
  [ $? -eq 1 ] && main

  case $_OS_TYPE in
    deb)
      wget -q -O - http://pkg.jenkins-ci.org/debian$_STABLE/jenkins-ci.org.key | apt-key add -

      run_as_root "echo \"deb http://pkg.jenkins-ci.org/debian$_STABLE binary/\" > /etc/apt/sources.list.d/jenkins.list"

      $_PACKAGE_COMMAND update

      $_PACKAGE_COMMAND -y install jenkins

      change_file "replace" "/etc/default/jenkins" "^HTTP_PORT=8080" "HTTP_PORT=$_HTTP_PORT"
      ;;
    rpm)
      wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat$_STABLE/jenkins.repo

      rpm --import https://jenkins-ci.org/redhat$_STABLE/jenkins-ci.org.key

      $_PACKAGE_COMMAND -y install jenkins

      chkconfig jenkins on

      change_file "replace" "/etc/sysconfig/jenkins" "^JENKINS_PORT=\"8080\"" "JENKINS_PORT=\"$_HTTP_PORT\""
      ;;
  esac

  service jenkins restart

  message "Notice" "Jenkins successfully installed!"
}

configure_nginx () {
  _PORT=$(cat /etc/default/jenkins | grep "^HTTP_PORT=" | cut -d= -f2)
  _DEFAULT_HOST="localhost:$_PORT"

  if command -v nginx > /dev/null; then
    _DOMAIN=$(input "Enter the domain of Jenkins" "jenkins.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input "Enter the host of Jenkins server" "$_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_URL_CENTRAL/scripts/templates/nginx/redirect.conf" > jenkins.conf

    change_file replace jenkins.conf APP jenkins
    change_file replace jenkins.conf DOMAIN $_DOMAIN
    change_file replace jenkins.conf HOST $_HOST

    mv jenkins.conf /etc/nginx/conf.d/
    rm jenkins.conf*

    service nginx restart

    message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed!"
  fi
}

main () {
  tool_check wget
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