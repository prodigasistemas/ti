#!/bin/bash
# http://www.redmine.org/projects/redmine/wiki/RedmineInstall
# http://www.redmine.org/projects/redmine/wiki/EmailConfiguration
# http://www.redmine.org/projects/redmine/wiki/Install_Redmine_25x_on_Centos_65_complete
# http://stackoverflow.com/questions/4598001/how-do-you-find-the-original-user-through-multiple-sudo-and-su-commands

export _APP_NAME="Redmine"
_REDMINE_LAST_VERSION="3.4.7"
_DEFAULT_PATH="/opt"

_REDMINE_FOLDER="$_DEFAULT_PATH/redmine"
_DOWNLOADS_FOLDER="$_REDMINE_FOLDER/downloads"
_VERSIONS_FOLDER="$_REDMINE_FOLDER/versions"
_SHARED_FOLDER="$_REDMINE_FOLDER/shared"
_CURRENT_FOLDER="$_REDMINE_FOLDER/current"

_TEMP_DIRS="cache imports pdf pids sessions sockets test thumbnails"

_OPTIONS_LIST="install_redmine 'Install the Redmine $_REDMINE_LAST_VERSION in $_DEFAULT_PATH' \
               configure_email 'Configure sending email' \
               configure_nginx 'Configure host on NGINX' \
               agile_plugin 'Install Redmine Agile plugin' \
               issue_reports_plugin 'Install Redmine issue reports plugin'"

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

install_dependencies () {
  [ "$_OS_TYPE" = "deb" ] && _PACKAGES="libmagickwand-dev libgmp3-dev"
  [ "$_OS_TYPE" = "rpm" ] && _PACKAGES="ImageMagick-devel"

  print_colorful white bold "> Installing dependencies..."

  $_PACKAGE_COMMAND -y install $_PACKAGES
}

configure_database () {
  _YAML_FILE="$_SHARED_FOLDER/config/database.yml"

  if [ ! -e "$_YAML_FILE" ]; then
    _DB_HOST=$(input_field "[default]" "Enter the host of the Database Server" "localhost")
    [ $? -eq 1 ] && main
    [ -z "$_DB_HOST" ] && message "Alert" "The host of the Database Server can not be blank!"

    print_colorful white bold "> Configuring database..."

    cd $_REDMINE_FOLDER

    echo "postgresql.database.name = redmine" > recipe.ti
    echo "postgresql.database.user.name = redmine" >> recipe.ti
    echo "postgresql.database.user.password = redmine" >> recipe.ti

    curl -sS $_CENTRAL_URL_TOOLS/scripts/install/postgresql/linux.sh | bash

    delete_file recipe.ti

    echo "production:" > $_YAML_FILE
    echo "  adapter: postgresql" >> $_YAML_FILE
    echo "  url: postgres://redmine:redmine@$_DB_HOST:5432/redmine" >> $_YAML_FILE

    chown "$_USER_LOGGED":"$_USER_GROUP" $_YAML_FILE
  fi

  make_symbolic_link "$_YAML_FILE" "$_CURRENT_FOLDER/config/database.yml"
}

make_folders () {
  mkdir -p $_REDMINE_FOLDER/{downloads,versions}
  mkdir -p $_SHARED_FOLDER/{bundle,config,files,log,plugins}

  for temp_dir in $_TEMP_DIRS; do
    mkdir -p $_SHARED_FOLDER/tmp/$temp_dir
  done
}

make_links () {
  _VERSION=$1

  make_symbolic_link "$_VERSIONS_FOLDER/$_VERSION" "$_CURRENT_FOLDER"

  make_symbolic_link "$_SHARED_FOLDER/files" "$_VERSIONS_FOLDER/$_VERSION/files"

  make_symbolic_link "$_SHARED_FOLDER/log" "$_VERSIONS_FOLDER/$_VERSION/log"

  for temp_dir in $_TEMP_DIRS; do
    make_symbolic_link "$_SHARED_FOLDER/tmp/$temp_dir" "$_VERSIONS_FOLDER/$_VERSION/tmp/$temp_dir"
  done
}

puma_restart () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")
  _PUMA_STATE=$_SHARED_FOLDER/tmp/pids/puma.state

  if [ -e "$_PUMA_STATE" ]; then
    run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && bundle exec pumactl -S $_PUMA_STATE -F $_SHARED_FOLDER/puma.rb restart"
  fi
}

install_redmine () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")
  _USER_GROUP=$(echo "$(groups "$_USER_LOGGED" | cut -d: -f2)" | cut -d' ' -f1)
  _RUBY_LAST_VERSION=$(run_as_user "$_USER_LOGGED" "ruby -v | cut -d' ' -f2 | cut -d'p' -f1")

  _RUBY_INSTALLED=$(run_as_user "$_USER_LOGGED" "command -v ruby")
  [ -z "$_RUBY_INSTALLED" ] && message "Alert" "Ruby language is not installed!"

  _RVM_INSTALLED=$(run_as_user "$_USER_LOGGED" "command -v rvm")
  [ -z "$_RVM_INSTALLED" ] && message "Alert" "RVM is not installed!"

  _POSTGRESQL_INSTALLED=$(run_as_user "$_USER_LOGGED" "command -v psql")
  [ -z "$_POSTGRESQL_INSTALLED" ] && message "Alert" "PostgreSQL Client or Server is not installed!"

  _RUBY_VERSION=$(input_field "ruby.version" "Ruby version" "$_RUBY_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_RUBY_VERSION" ] && message "Alert" "The Ruby version can not be blank!"

  _REDMINE_VERSION=$(input_field "redmine.version" "Redmine version" "$_REDMINE_LAST_VERSION")
  [ $? -eq 1 ] && main
  [ -z "$_REDMINE_VERSION" ] && message "Alert" "The Redmine version can not be blank!"

  _LANGUAGE=$(input_field "redmine.language" "Redmine language" "pt-BR")
  [ $? -eq 1 ] && main
  [ -z "$_LANGUAGE" ] && _LANGUAGE=pt-BR

  confirm "Confirm installation Redmine $_REDMINE_VERSION?" "Redmine installer"
  [ $? -eq 1 ] && main

  install_dependencies

  print_colorful yellow bold "> Downloading Redmine $_REDMINE_VERSION..."

  _REDMINE_PACKAGE=redmine-$_REDMINE_VERSION.tar.gz

  make_folders

  [ -e "$_VERSIONS_FOLDER/$_REDMINE_VERSION" ] && message "Alert" "Redmine $_REDMINE_VERSION is already installed."

  cd $_DOWNLOADS_FOLDER

  if [ ! -e "$_DOWNLOADS_FOLDER/$_REDMINE_PACKAGE" ]; then
    wget "http://www.redmine.org/releases/$_REDMINE_PACKAGE"

    [ $? -ne 0 ] && message "Error" "Download of file $_REDMINE_PACKAGE unrealized!"
  fi

  tar -xzf $_REDMINE_PACKAGE

  mv "redmine-$_REDMINE_VERSION" "$_VERSIONS_FOLDER/$_REDMINE_VERSION"

  make_links $_REDMINE_VERSION

  configure_database

  chown "$_USER_LOGGED":"$_USER_GROUP" -R $_REDMINE_FOLDER

  print_colorful white bold "> Installing gems..."

  run_as_user "$_USER_LOGGED" "echo \"ruby '$_RUBY_VERSION'\" > $_CURRENT_FOLDER/Gemfile.local"
  run_as_user "$_USER_LOGGED" "echo \"gem 'puma'\" >> $_CURRENT_FOLDER/Gemfile.local"
  run_as_user "$_USER_LOGGED" "echo \"gem 'holidays'\" >> $_CURRENT_FOLDER/Gemfile.local"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && bundle install --without development test --path $_SHARED_FOLDER/bundle"

  print_colorful white bold "> Running data migration..."

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle exec rake db:migrate"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production REDMINE_LANG=$_LANGUAGE bundle exec rake redmine:load_default_data"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle exec rake tmp:cache:clear"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle exec rake generate_secret_token"

  print_colorful white bold "> Starting Redmine..."

  _PUMA_FILE="puma.rb"

  curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/puma/puma.rb" > $_PUMA_FILE

  [ $? -ne 0 ] && message "Error" "Download of file puma.rb unrealized!"

  change_file replace $_PUMA_FILE "APP_NAME" "redmine"
  change_file replace $_PUMA_FILE "APP_PATH" "$_DEFAULT_PATH"

  chown "$_USER_LOGGED":"$_USER_GROUP" $_PUMA_FILE

  mv $_PUMA_FILE $_SHARED_FOLDER

  cd $_REDMINE_FOLDER

  echo "puma.ruby.version = $_RUBY_VERSION" > recipe.ti
  echo "puma.user.name = $_USER_LOGGED" >> recipe.ti
  echo "puma.service.name = redmine" >> recipe.ti
  echo "puma.service.path = /opt" >> recipe.ti

  curl -sS $_CENTRAL_URL_TOOLS/scripts/install/puma/linux.sh | bash

  delete_file recipe.ti

  [ $? -eq 0 ] && message "Notice" "Redmine $_REDMINE_VERSION successfully installed!"
}

configure_email () {
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")
  _CONFIG_FILE=$_SHARED_FOLDER/config/configuration.yml

  _DOMAIN=$(input_field "redmine.email.domain" "Enter the email domain" "company.com")
  [ $? -eq 1 ] && main
  [ -z "$_DOMAIN" ] && message "Alert" "The email domain can not be blank!"

  _SMTP_ADDRESS=$(input_field "redmine.email.smtp.address" "Enter the email SMTP address" "smtp.$_DOMAIN")
  [ $? -eq 1 ] && main
  [ -z "$_SMTP_ADDRESS" ] && message "Alert" "The email SMTP address can not be blank!"

  _SMTP_PORT=$(input_field "redmine.email.smtp.port" "Enter the email SMTP port" "25")
  [ $? -eq 1 ] && main
  [ -z "$_SMTP_PORT" ] && message "Alert" "The email SMTP port can not be blank!"

  _USER_NAME=$(input_field "redmine.email.user.name" "Enter the email user name")
  [ $? -eq 1 ] && main
  [ -z "$_USER_NAME" ] && message "Alert" "The email user name can not be blank!"

  _USER_PASSWORD=$(input_field "redmine.email.user.password" "Enter the email user password")
  [ $? -eq 1 ] && main
  [ -z "$_USER_PASSWORD" ] && message "Alert" "The email user password can not be blank!"

  confirm "Domain: $_DOMAIN\nSMTP: $_SMTP_ADDRESS\nUser: $_USER_NAME\nPassword: $_USER_PASSWORD\nConfirm?" "Configure sending email"
  [ $? -eq 1 ] && main

  if [ ! -e "$_CONFIG_FILE" ]; then
    print_colorful white bold "> Configuring sending email..."

    echo "production:" > $_CONFIG_FILE
    echo "email_delivery:" >> $_CONFIG_FILE
    echo "  delivery_method: :smtp" >> $_CONFIG_FILE
    echo "  smtp_settings:" >> $_CONFIG_FILE
    echo "    address: \"$_SMTP_ADDRESS\"" >> $_CONFIG_FILE
    echo "    port: $_SMTP_PORT" >> $_CONFIG_FILE
    echo "    authentication: :login" >> $_CONFIG_FILE
    echo "    domain: '$_DOMAIN'" >> $_CONFIG_FILE
    echo "    user_name: '$_USER_NAME'" >> $_CONFIG_FILE
    echo "    password: '$_USER_PASSWORD'" >> $_CONFIG_FILE

    chown "$_USER_LOGGED":"$_USER_GROUP" $_CONFIG_FILE
  fi

  make_symbolic_link "$_CONFIG_FILE" "$_CURRENT_FOLDER/config/configuration.yml"

  puma_restart

  [ $? -eq 0 ] && message "Notice" "Sending email is successfully configured!"
}

configure_nginx () {
  which nginx > /dev/null
  [ $? -ne 0 ] && message "Alert" "NGINX Web Server is not installed!"

  _DOMAIN=$(input_field "redmine.nginx.domain" "Enter the domain of Redmine" "redmine.company.gov")
  [ $? -eq 1 ] && main
  [ -z "$_DOMAIN" ] && message "Alert" "The domain can not be blank!"

  if [ ! -e "/etc/nginx/conf.d/redmine.conf" ]; then
    curl -sS "$_CENTRAL_URL_TOOLS/scripts/templates/nginx/ruby_on_rails.conf" > redmine.conf

    [ $? -ne 0 ] && message "Error" "Download of file ruby_on_rails.conf unrealized!"

    change_file replace redmine.conf DOMAIN "$_DOMAIN"
    change_file replace redmine.conf APP_NAME "redmine"
    change_file replace redmine.conf APP_PATH "$_DEFAULT_PATH"

    mv redmine.conf /etc/nginx/conf.d/
    rm $_SED_BACKUP_FOLDER/redmine.conf*

    admin_service nginx restart

    [ $? -eq 0 ] && message "Notice" "The host is successfully configured in NGINX!"
  fi
}

agile_plugin () {
  confirm "Confirm installation Redmine Agile Plugin?"
  [ $? -eq 1 ] && main

  _AGILE_PLUGIN_FOLDER=$_CURRENT_FOLDER/plugins/redmine_agile

  print_colorful white bold "> Configuring agile plugin..."

  cd /tmp

  wget "https://www.dropbox.com/s/wmkku66ma2io7n5/redmine_agile.zip"

  [ $? -ne 0 ] && message "Error" "Download of file redmine_agile.zip unrealized!"

  unzip -oq redmine_agile.zip
  rm redmine_agile.zip
  rm -rf $_SHARED_FOLDER/plugins/redmine_agile
  mv "redmine_agile" "$_SHARED_FOLDER/plugins/"
  chown "$_USER_LOGGED":"$_USER_GROUP" -R "$_SHARED_FOLDER/plugins/redmine_agile"

  make_symbolic_link "$_SHARED_FOLDER/plugins/redmine_agile" "$_AGILE_PLUGIN_FOLDER"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle install --without development test"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle exec rake redmine:plugins NAME=redmine_agile"

  run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle exec rake redmine:plugins:migrate"

  puma_restart

  [ $? -eq 0 ] && message "Notice" "Redmine Agile plugin is successfully configured!"
}

issue_reports_plugin () {
  confirm "Confirm installation Redmine Issue Reports Plugin?"
  [ $? -eq 1 ] && main

  _ISSUE_REPORTS_FOLDER=$_CURRENT_FOLDER/plugins/redmine_issue_reports

  if [ ! -e "$_SHARED_FOLDER/plugins/redmine_issue_reports" ]; then
    _POSTGRESQL_CHECK=$(command -v psql)
    [ -z "$_POSTGRESQL_CHECK" ] && message "Alert" "The PostgreSQL Client is not installed!"

    _POSTGRESQL_HOST=$(input_field "[default]" "Enter the host of the PostgreSQL Server" "localhost")
    [ $? -eq 1 ] && main
    [ -z "$_POSTGRESQL_HOST" ] && message "Alert" "The host of the PostgreSQL Server can not be blank!"

    _POSTGRESQL_PORT=$(input_field "[default]" "Enter the port of the PostgreSQL Server" "5432")
    [ $? -eq 1 ] && main
    [ -z "$_POSTGRESQL_PORT" ] && message "Alert" "The port of the PostgreSQL Server can not be blank!"

    print_colorful white bold "> Configuring issue reports plugin..."

    cd /tmp

    wget "https://github.com/prodigasistemas/redmine_issue_reports/archive/master.zip"

    [ $? -ne 0 ] && message "Error" "Download of file master.zip unrealized!"

    unzip -oq master.zip
    rm master.zip
    mv "redmine_issue_reports-master" "$_SHARED_FOLDER/plugins/redmine_issue_reports"
    chown "$_USER_LOGGED":"$_USER_GROUP" -R $_SHARED_FOLDER/plugins/redmine_issue_reports

    make_symbolic_link "$_SHARED_FOLDER/plugins/redmine_issue_reports" "$_ISSUE_REPORTS_FOLDER"

    cp "$_ISSUE_REPORTS_FOLDER/config/config.example.yml" "$_ISSUE_REPORTS_FOLDER/config/config.yml"

    import_database "postgresql" "$_POSTGRESQL_HOST" "$_POSTGRESQL_PORT" "redmine" "redmine" "redmine" "$_ISSUE_REPORTS_FOLDER/update-redmine/postgresql_config.sql"
  else
    make_symbolic_link "$_SHARED_FOLDER/plugins/redmine_issue_reports" "$_ISSUE_REPORTS_FOLDER"

    run_as_user "$_USER_LOGGED" "cd $_CURRENT_FOLDER && RAILS_ENV=production bundle exec rake redmine:plugins:migrate"
  fi

  puma_restart

  cp "$_ISSUE_REPORTS_FOLDER/update-redmine/custom_fields.js" "$_CURRENT_FOLDER/public/javascripts"

  _ISSUE_FORM_FILE=$_CURRENT_FOLDER/app/views/issues/_form.html.erb
  _FIND_TAG=$(grep custom_fields "$_ISSUE_FORM_FILE")

  [ -z "$_FIND_TAG" ] && echo "<%= javascript_include_tag 'custom_fields' %>" >> $_ISSUE_FORM_FILE

  [ $? -eq 0 ] && message "Notice" "Redmine Issue reports plugin is successfully configured!"
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
    [ "$(search_value redmine.plugin.agile)" = "yes" ] && agile_plugin
    [ "$(search_value redmine.plugin.issue.reports)" = "yes" ] && issue_reports_plugin
  fi
}

setup
main
