#!/bin/bash

# https://wiki.jenkins-ci.org/display/JENKINS/Installing+Jenkins+on+Ubuntu
# https://wiki.jenkins-ci.org/display/JENKINS/Installing+Jenkins+on+Red+Hat+distributions

export _APP_NAME="Jenkins"
_OPTIONS_LIST="install_jenkins 'Install Jenkins' \
               configure_nginx 'Configure host on NGINX'"

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

install_jenkins () {
  java_check 7

  _JAVA_HOME=$(get_java_home 7)

  _HTTP_PORT=$(input_field "jenkins.http.port" "Enter the http port for Jenkins" "8085")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  _JAVA_COMMAND=$(input_field "[default]" "Enter the path of command Java 7" "$_JAVA_HOME/bin/java")
  [ $? -eq 1 ] && main
  [ -z "$_JAVA_COMMAND" ] && message "Alert" "The Java command can not be blank!"

  if [ "$(provisioning)" = "manual" ]; then
    confirm "Do you want to download the stable repository?"
    [ $? -eq 0 ] && _STABLE="-stable"
  fi

  confirm "Do you confirm the installation of Jenkins$_STABLE?"
  [ $? -eq 1 ] && main

  case "$_OS_TYPE" in
    deb)
      wget -q -O - "https://pkg.jenkins.io/debian$_STABLE/jenkins.io.key" | sudo apt-key add -

      run_as_root "echo \"deb https://pkg.jenkins.io/debian$_STABLE binary/\" > /etc/apt/sources.list.d/jenkins.list"

      $_PACKAGE_COMMAND update

      $_PACKAGE_COMMAND -y install jenkins

      change_file "replace" "/etc/default/jenkins" "^HTTP_PORT=8080" "HTTP_PORT=$_HTTP_PORT"
      change_file "replace" "/etc/default/jenkins" "^JAVA=/usr/bin/java" "JAVA=$_JAVA_COMMAND"
      ;;
    rpm)
      wget -O "/etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat$_STABLE/jenkins.repo"

      rpm --import "https://pkg.jenkins.io/redhat$_STABLE/jenkins.io.key"

      $_PACKAGE_COMMAND -y install jenkins

      admin_service jenkins register

      change_file "replace" "/etc/sysconfig/jenkins" "^JENKINS_PORT=\"8080\"" "JENKINS_PORT=\"$_HTTP_PORT\""
      change_file "replace" "/etc/sysconfig/jenkins" "^JENKINS_JAVA_CMD=\"\"" "JENKINS_JAVA_CMD=\"$_JAVA_COMMAND\""
      ;;
  esac

  admin_service jenkins restart

  [ $? -eq 0 ] && message "Notice" "Jenkins successfully installed!"
}

configure_nginx () {
  _PORT=$(grep "^HTTP_PORT=" /etc/default/jenkins | cut -d= -f2)
  _DEFAULT_HOST="localhost:$_PORT"

  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "jenkins.nginx.domain" "Enter the domain of Jenkins" "jenkins.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input_field "jenkins.nginx.host" "Enter the host of Jenkins server" "$_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > jenkins.conf

    change_file replace jenkins.conf APP jenkins
    change_file replace jenkins.conf DOMAIN "$_DOMAIN"
    change_file replace jenkins.conf HOST "$_HOST"

    mv jenkins.conf /etc/nginx/conf.d/
    rm jenkins.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed! Jenkins host not configured!"
  fi
}

main () {
  tool_check wget

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_OPTION" ]; then
      clear && exit 0
    else
      $_OPTION
    fi
  else
    [ -n "$(search_app jenkins.http.port)" ] && install_jenkins
    [ -n "$(search_app jenkins.nginx)" ] && configure_nginx
  fi
}

setup
main
