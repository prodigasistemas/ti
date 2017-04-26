#!/bin/bash
# http://www.redmine.org/projects/redmine/wiki/RedmineInstall
# http://www.redmine.org/projects/redmine/wiki/EmailConfiguration
# http://www.redmine.org/projects/redmine/wiki/Install_Redmine_25x_on_Centos_65_complete
# http://stackoverflow.com/questions/4598001/how-do-you-find-the-original-user-through-multiple-sudo-and-su-commands

_APP_NAME="Redmine"
_REDMINE_LAST_VERSION="3.3.0"
_DEFAULT_PATH="/opt"
_REDMINE_FOLDER="$_DEFAULT_PATH/redmine"

_OPTIONS_LIST="install_redmine 'Install the Redmine $_REDMINE_LAST_VERSION in $_DEFAULT_PATH' \
               configure_email 'Configure sending email' \
               configure_nginx 'Configure host on NGINX' \
               issue_reports_plugin 'Install Redmine issue reports plugin'"

setup () {
  [ -z "$_CENTRAL_URL_TOOLS" ] && _CENTRAL_URL_TOOLS="https://prodigasistemas.github.io"

  ping -c 1 $(echo $_CENTRAL_URL_TOOLS | sed 's|http.*://||g' | cut -d: -f1) > /dev/null
  [ $? -ne 0 ] && echo "$_CENTRAL_URL_TOOLS connection was not successful!" && exit 1

  _FUNCTIONS_FILE="/tmp/.tools.installer.functions.linux.sh"

  curl -sS $_CENTRAL_URL_TOOLS/scripts/functions/linux.sh > $_FUNCTIONS_FILE 2> /dev/null
  [ $? -ne 0 ] && echo "Functions were not loaded!" && exit 1

  [ -e "$_FUNCTIONS_FILE" ] && source $_FUNCTIONS_FILE && rm $_FUNCTIONS_FILE

  os_check
}

install_dependencies () {
  [ "$_OS_TYPE" = "deb" ] && _PACKAGES="libmagickwand-dev libgmp3-dev"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGES="ImageMagick-devel"

  print_colorful white bold "> Installing dependencies..."

  $_PACKAGE_COMMAND -y install $_PACKAGES
}

configure_database () {
  _YAML_FILE="$_REDMINE_FOLDER/config/database.yml"

  _MYSQL_HOST=$(input_field "[default]" "Enter the host of the MySQL Server" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_HOST" ] && message "Alert" "The host of the MySQL Server can not be blank!"

  _MYSQL_ROOT_PASSWORD=$(input_field "redmine.mysql.root.password" "Enter the password of the root user in MySQL")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_ROOT_PASSWORD" ] && message "Alert" "The root password can not be blank!"

  _MYSQL_REDMINE_PASSWORD=$(input_field "redmine.mysql.user.password" "Enter the password of the redmine user in MySQL")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_REDMINE_PASSWORD" ] && message "Alert" "The redmine password can not be blank!"

  print_colorful white bold "> Configuring database..."

  mysql_as_root $_MYSQL_ROOT_PASSWORD "DROP DATABASE IF EXISTS redmine;"
  mysql_as_root $_MYSQL_ROOT_PASSWORD "CREATE DATABASE redmine CHARACTER SET utf8;"
  mysql_as_root $_MYSQL_ROOT_PASSWORD "CREATE USER redmine@$_MYSQL_HOST IDENTIFIED BY '$_MYSQL_REDMINE_PASSWORD';"
  mysql_as_root $_MYSQL_ROOT_PASSWORD "GRANT ALL PRIVILEGES ON redmine.* TO redmine@$_MYSQL_HOST WITH GRANT OPTION;"
  mysql_as_root $_MYSQL_ROOT_PASSWORD "FLUSH PRIVILEGES;"

  echo "production:" > $_YAML_FILE
  echo "  adapter: mysql2" >> $_YAML_FILE
  echo "  database: redmine" >> $_YAML_FILE
  echo "  host: $_MYSQL_HOST" >> $_YAML_FILE
  echo "  username: redmine" >> $_YAML_FILE
  echo "  password: \"$_MYSQL_REDMINE_PASSWORD\"" >> $_YAML_FILE
  echo "  encoding: utf8" >> $_YAML_FILE
}

install_redmine () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")
  _USER_GROUP=$(echo $(groups $_USER_LOGGED | cut -d: -f2) | cut -d' ' -f1)
  _USER_GROUPS=$(echo $(groups $_USER_LOGGED | cut -d: -f2))

  _RUBY_INSTALLED=$(run_as_user $_USER_LOGGED "command -v ruby")
  [ -z "$_RUBY_INSTALLED" ] && message "Alert" "Ruby language is not installed!"

  _RVM_INSTALLED=$(run_as_user $_USER_LOGGED "command -v rvm")
  [ -z "$_RVM_INSTALLED" ] && message "Alert" "Ruby Version Manager (RVM) is not installed!"

  _MYSQL_INSTALLED=$(run_as_user $_USER_LOGGED "command -v mysql")
  [ -z "$_MYSQL_INSTALLED" ] && message "Alert" "MySQL Client or Server is not installed!"

  _REDMINE_VERSION=$(input_field "redmine.version" "Redmine version" "$_REDMINE_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_REDMINE_VERSION" ] && message "Alert" "The Redmine version can not be blank!"

  confirm "Confirm installation Redmine $_REDMINE_VERSION?" "Redmine installer"
  [ $? -eq 1 ] && main

  install_dependencies

  print_colorful white bold "> Downloading Redmine..."

  wget http://www.redmine.org/releases/redmine-$_REDMINE_VERSION.tar.gz

  [ $? -ne 0 ] && message "Error" "Download of file redmine-$_REDMINE_VERSION.tar.gz unrealized!"

  tar -xzf redmine-$_REDMINE_VERSION.tar.gz

  rm redmine-$_REDMINE_VERSION.tar.gz

  backup_folder $_REDMINE_FOLDER

  mv redmine-$_REDMINE_VERSION $_REDMINE_FOLDER

  configure_database

  chown $_USER_LOGGED:$_USER_GROUP -R $_REDMINE_FOLDER

  run_as_user $_USER_LOGGED "echo \"gem 'unicorn'\" > $_REDMINE_FOLDER/Gemfile.local"
  run_as_user $_USER_LOGGED "echo \"gem 'holidays'\" >> $_REDMINE_FOLDER/Gemfile.local"
  run_as_user $_USER_LOGGED "gem install bundler"

  print_colorful white bold "> Installing gems..."

  run_as_user $_USER_LOGGED "cd $_REDMINE_FOLDER && bundle install --without development test --path $_REDMINE_FOLDER/vendor/bundle"

  print_colorful white bold "> Running data migration..."

  run_as_user $_USER_LOGGED "cd $_REDMINE_FOLDER && RAILS_ENV=production bundle exec rake db:migrate"

  run_as_user $_USER_LOGGED "cd $_REDMINE_FOLDER && RAILS_ENV=production REDMINE_LANG=pt-BR bundle exec rake redmine:load_default_data"

  run_as_user $_USER_LOGGED "cd $_REDMINE_FOLDER && RAILS_ENV=production bundle exec rake generate_secret_token"

  print_colorful white bold "> Setting Redmine..."

  _UNICORN_RB_FILE="unicorn.rb"
  curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/unicorn/unicorn.rb" > $_UNICORN_RB_FILE

  [ $? -ne 0 ] && message "Error" "Download of file unicorn.rb unrealized!"

  change_file replace $_UNICORN_RB_FILE "__APP__" "redmine"
  change_file replace $_UNICORN_RB_FILE "__PATH__" "$_DEFAULT_PATH"
  chown $_USER_LOGGED:$_USER_GROUP $_UNICORN_RB_FILE
  mv $_UNICORN_RB_FILE $_REDMINE_FOLDER/config
  rm $_UNICORN_RB_FILE*

  _UNICORN_INIT_FILE="unicorn_init.sh"
  curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/unicorn/unicorn_init.sh" > $_UNICORN_INIT_FILE

  [ $? -ne 0 ] && message "Error" "Download of file unicorn_init.sh unrealized!"

  change_file replace $_UNICORN_INIT_FILE "__APP__" "redmine"
  change_file replace $_UNICORN_INIT_FILE "__PATH__" "$_DEFAULT_PATH"
  change_file replace $_UNICORN_INIT_FILE "__USER__" "$_USER_LOGGED"
  chown $_USER_LOGGED:$_USER_GROUP $_UNICORN_INIT_FILE
  chmod +x $_UNICORN_INIT_FILE
  mv $_UNICORN_INIT_FILE $_REDMINE_FOLDER/config
  rm $_UNICORN_INIT_FILE*
  ln -sf $_REDMINE_FOLDER/config/$_UNICORN_INIT_FILE /etc/init.d/unicorn_redmine

  print_colorful white bold "> Starting Redmine..."

  admin_service unicorn_redmine register

  admin_service unicorn_redmine start

  [ $? -eq 0 ] && message "Notice" "Redmine $_REDMINE_VERSION successfully installed! For test: cd $_REDMINE_FOLDER && RAILS_ENV=production bundle exec rails server --binding=[SERVER-IP]"
}

configure_email () {
  _DOMAIN=$(input_field "redmine.email.domain" "Enter the email domain" "company.com")
  [ $? -eq 1 ] && main
  [ -z "$_DOMAIN" ] && message "Alert" "The email domain can not be blank!"

  _SMTP_ADDRESS=$(input_field "redmine.email.smtp" "Enter the email SMTP address" "smtp.$_DOMAIN")
  [ $? -eq 1 ] && main
  [ -z "$_SMTP_ADDRESS" ] && message "Alert" "The email SMTP address can not be blank!"

  _USER_NAME=$(input_field "redmine.email.user.name" "Enter the email user name")
  [ $? -eq 1 ] && main
  [ -z "$_USER_NAME" ] && message "Alert" "The email user name can not be blank!"

  _USER_PASSWORD=$(input_field "redmine.email.user.password" "Enter the email user password")
  [ $? -eq 1 ] && main
  [ -z "$_USER_PASSWORD" ] && message "Alert" "The email user password can not be blank!"

  confirm "Domain: $_DOMAIN\nSMTP: $_SMTP_ADDRESS\nUser: $_USER_NAME\nPassword: $_USER_PASSWORD\nConfirm?" "Configure sending email"
  [ $? -eq 1 ] && main

  print_colorful white bold "> Configuring sending e-mail..."

  _CONFIG_FILE=$_REDMINE_FOLDER/config/configuration.yml

  echo "production:" > $_CONFIG_FILE
  echo "email_delivery:" >> $_CONFIG_FILE
  echo "  delivery_method: :smtp" >> $_CONFIG_FILE
  echo "  smtp_settings:" >> $_CONFIG_FILE
  echo "    address: \"$_SMTP_ADDRESS\"" >> $_CONFIG_FILE
  echo "    port: 25" >> $_CONFIG_FILE
  echo "    authentication: :login" >> $_CONFIG_FILE
  echo "    domain: '$_DOMAIN'" >> $_CONFIG_FILE
  echo "    user_name: '$_USER_NAME'" >> $_CONFIG_FILE
  echo "    password: '$_USER_PASSWORD'" >> $_CONFIG_FILE

  /etc/init.d/unicorn_redmine upgrade

  [ $? -eq 0 ] && message "Notice" "Sending email is successfully configured!"
}

configure_nginx () {
  if command -v nginx > /dev/null; then
    _DOMAIN=$(input_field "redmine.nginx.domain" "Enter the domain of Redmine" "redmine.company.gov")
    [ $? -eq 1 ] && main
    [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/ruby_on_rails.conf" > redmine.conf

    change_file replace redmine.conf APP "redmine"
    change_file replace redmine.conf DOMAIN "$_DOMAIN"
    change_file replace redmine.conf PATH "$_DEFAULT_PATH"

    mv redmine.conf /etc/nginx/conf.d/
    rm redmine.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  else
    message "Alert" "NGINX is not installed! Redmine host not configured!"
  fi
}

issue_reports_plugin () {
  _ISSUE_REPORTS_FOLDER=$_REDMINE_FOLDER/plugins/redmine_issue_reports

  _MYSQL_CHECK=$(command -v mysql)
  [ -z "$_MYSQL_CHECK" ] && message "Alert" "The MySQL Client is not installed!"

  _MYSQL_HOST=$(input_field "[default]" "Enter the host of the MySQL Server" "localhost")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_HOST" ] && message "Alert" "The host of the MySQL Server can not be blank!"

  _MYSQL_PORT=$(input_field "[default]" "Enter the port of the MySQL Server" "3306")
  [ $? -eq 1 ] && main
  [ -z "$_MYSQL_PORT" ] && message "Alert" "The port of the MySQL Server can not be blank!"

  _USER_PASSWORD=$(input_field "redmine.mysql.user.password" "Enter the redmine password in database")
  [ $? -eq 1 ] && main
  [ -z "$_USER_PASSWORD" ] && message "Alert" "The redmine password can not be blank!"

  print_colorful white bold "> Configuring issue reports plugin..."

  wget https://github.com/prodigasistemas/redmine_issue_reports/archive/master.zip

  [ $? -ne 0 ] && message "Error" "Download of file master.zip unrealized!"

  unzip -oq master.zip
  rm master.zip
  mv redmine_issue_reports-master $_ISSUE_REPORTS_FOLDER

  cp $_ISSUE_REPORTS_FOLDER/config/config.example.yml $_ISSUE_REPORTS_FOLDER/config/config.yml
  cp $_ISSUE_REPORTS_FOLDER/update-redmine/custom_fields.js $_REDMINE_FOLDER/public/javascripts

  _ISSUE_FORM_FILE=$_REDMINE_FOLDER/app/views/issues/_form.html.erb
  _FIND_TAG=$(cat $_ISSUE_FORM_FILE | grep custom_fields)

  [ -z "$_FIND_TAG" ] && echo "<%= javascript_include_tag 'custom_fields' %>" >> $_ISSUE_FORM_FILE

  import_database "mysql" "$_MYSQL_HOST" "$_MYSQL_PORT" "redmine" "redmine" "$_USER_PASSWORD" "$_ISSUE_REPORTS_FOLDER/update-redmine/redmine_config.sql"

  [ $? -eq 0 ] && message "Notice" "Issue reports plugin is successfully configured!"
}

main () {
  tool_check curl
  tool_check unzip
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
    [ -n "$(search_app redmine)" ] && install_redmine
    [ -n "$(search_app redmine.nginx)" ] && configure_nginx
    [ -n "$(search_app redmine.email)" ] && configure_email
    [ "$(search_value redmine.issue.reports.plugin)" = "yes" ] && issue_reports_plugin
  fi
}

setup
main
