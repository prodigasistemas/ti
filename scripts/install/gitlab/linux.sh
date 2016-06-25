#!/bin/bash

# http://docs.gitlab.com/ce/install/requirements.html
# https://about.gitlab.com/downloads/#ubuntu1404
# https://about.gitlab.com/downloads/#centos6

_APP_NAME="GitLab"
_HTTP_PORT_DEFAULT="7070"
_NGINX_DEFAULT_HOST="localhost:$_HTTP_PORT_DEFAULT"
_GITLAB_CONFIG="/etc/gitlab/gitlab.rb"
_GITLAB_STRING_SEARCH="external_url"

_OPTIONS_LIST="install_gitlab 'Install the GitLab' \
               configure_email 'Configure sending email' \
               configure_nginx 'Configure host on NGINX'"

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

install_gitlab () {
  _HTTP_PORT=$(input_field "gitlab.http.port" "Enter the http port for $_APP_NAME" "$_HTTP_PORT_DEFAULT")
  [ $? -eq 1 ] && main
  [ -z "$_HTTP_PORT" ] && message "Alert" "The http port can not be blank!"

  _UNICORN_PORT=$(input_field "gitlab.unicorn.port" "Enter the Unicorn port for $_APP_NAME" "6060")
  [ $? -eq 1 ] && main
  [ -z "$_UNICORN_PORT" ] && message "Alert" "The http port can not be blank!"

  _DOMAIN=$(input_field "gitlab.nginx.domain" "Enter the domain of $_APP_NAME" "gitlab.company.gov")
  [ $? -eq 1 ] && main
  [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

  _SHELL_SSH_PORT=$(input_field "gitlab.shell.ssh.port" "Enter the shell SSH port of $_APP_NAME" "22")
  [ $? -eq 1 ] && main
  [ -z "$_SHELL_SSH_PORT" ] && message "Alert" "The shell SSH port can not be blank!"

  _POSTGRESQL_SHARED_BUFFERS=$(input_field "gitlab.postgresql.shared.buffers" "Enter the size for PostgreSQL shared buffers of $_APP_NAME" "2GB")
  [ $? -eq 1 ] && main
  [ -z "$_POSTGRESQL_SHARED_BUFFERS" ] && message "Alert" "The size for PostgreSQL shared buffers can not be blank!"

  confirm "Do you confirm the installation of $_APP_NAME?"
  [ $? -eq 1 ] && main

  [ "$_OS_TYPE" = "deb" ] && _PACKAGES="openssh-server ca-certificates"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGES="openssh-server openssh-clients"

  curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.$_OS_TYPE.sh | bash

  $_PACKAGE_COMMAND -y install $_PACKAGES gitlab-ce

  _GITLAB_EXTERNAL_URL=$(cat $_GITLAB_CONFIG | egrep ^$_GITLAB_STRING_SEARCH)

  change_file "replace" "$_GITLAB_CONFIG" "^$_GITLAB_EXTERNAL_URL" "external_url 'http://$_DOMAIN'"

  if [ "$_SHELL_SSH_PORT" != "22" ]; then
    change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['gitlab_shell_ssh_port'] = $_SHELL_SSH_PORT"
  fi

  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "postgresql['shared_buffers'] = \"$_POSTGRESQL_SHARED_BUFFERS\""
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "unicorn['port'] = $_UNICORN_PORT"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "nginx['listen_port'] = $_HTTP_PORT"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "\ "
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "# General configuration"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "\ "

  # Sidekick configuration
  run_as_root "echo \"vm.overcommit_memory = 1\" >> /etc/sysctl.conf"

  if [ "$_OS_TYPE" = "deb" ]; then
    change_file "append" "/etc/rc.local" "# By default this script does nothing." "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    run_as_root "echo \"echo never > /sys/kernel/mm/transparent_hugepage/enabled\" >> /etc/rc.local"
  fi

  gitlab-ctl reconfigure

  [ $? -eq 0 ] && message "Notice" "$_APP_NAME successfully installed! Need you run the command: sudo reboot"
}

configure_email () {
  _DOMAIN=$(input_field "gitlab.email.domain" "Enter the email domain" "company.com")
  [ $? -eq 1 ] && main
  [ -z "$_DOMAIN" ] && message "Alert" "The email domain can not be blank!"

  _SMTP_ADDRESS=$(input_field "gitlab.email.smtp" "Enter the email SMTP address" "smtp.$_DOMAIN")
  [ $? -eq 1 ] && main
  [ -z "$_SMTP_ADDRESS" ] && message "Alert" "The email SMTP address can not be blank!"

  _USER_NAME=$(input_field "gitlab.email.user.name" "Enter the email user name")
  [ $? -eq 1 ] && main
  [ -z "$_USER_NAME" ] && message "Alert" "The email user name can not be blank!"

  _USER_PASSWORD=$(input_field "gitlab.email.user.password" "Enter the email user password")
  [ $? -eq 1 ] && main
  [ -z "$_USER_PASSWORD" ] && message "Alert" "The email user password can not be blank!"

  confirm "Domain: $_DOMAIN\nSMTP: $_SMTP_ADDRESS\nUser: $_USER_NAME\nPassword: $_USER_PASSWORD\nConfirm?" "Configure sending email"
  [ $? -eq 1 ] && main

  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_authentication'] = \"login\""
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_domain'] = \"$_DOMAIN\""
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_password'] = \"$_USER_PASSWORD\""
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_user_name'] = \"$_USER_NAME\""
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_port'] = 25"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_address'] = \"$_SMTP_ADDRESS\""
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['smtp_enable'] = true"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "\ "

  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['gitlab_email_display_name'] = 'gitlab'"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['gitlab_email_from'] = 'gitlab@$_DOMAIN'"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "gitlab_rails['gitlab_email_enabled'] = true"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "\ "

  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "# E-mail configuration"
  change_file "append" "$_GITLAB_CONFIG" "^$_GITLAB_STRING_SEARCH" "\ "

  gitlab-ctl reconfigure

  [ $? -eq 0 ] && message "Notice" "Sending email is successfully configured!"
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "gitlab.nginx.domain" "Enter the domain of $_APP_NAME" "gitlab.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    _HOST=$(input_field "gitlab.nginx.host" "Enter the host of $_APP_NAME server" "$_NGINX_DEFAULT_HOST")
    [ $? -eq 1 ] && main
    [ -z "$_HOST" ] && message "Alert" "The host can not be blank!"

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/redirect.conf" > gitlab.conf

    change_file "replace" "gitlab.conf" "APP" "gitlab"
    change_file "replace" "gitlab.conf" "DOMAIN" "$_DOMAIN"
    change_file "replace" "gitlab.conf" "HOST" "$_HOST"

    mv gitlab.conf /etc/nginx/conf.d/
    rm gitlab.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed!"
  fi
}

main () {
  tool_check curl
  tool_check wget

  if [ "$(provisioning)" = "manual" ]; then
    tool_check dialog

    _MAIN_OPTION=$(menu "Select the option" "$_OPTIONS_LIST")

    if [ -z "$_MAIN_OPTION" ]; then
      clear && exit 0
    else
      $_MAIN_OPTION
    fi
  else
    [ ! -z "$(search_app gitlab)" ] && install_gitlab
    [ ! -z "$(search_app gitlab.email)" ] && configure_email
    [ ! -z "$(search_app gitlab.nginx)" ] && configure_nginx
  fi
}

setup
main
