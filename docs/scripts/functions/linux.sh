#!/bin/bash
# http://www.thegeekstuff.com/2009/11/unix-sed-tutorial-append-insert-replace-and-count-file-lines/
# http://centoshowtos.org/blog/ifconfig-on-centos-7/

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ "$(which lsb_release 2>/dev/null)" ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_NUMBER=$(lsb_release -rs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(awk '{ print tolower($1) }' /etc/redhat-release)
    _OS_RELEASE=$(sed 's/CentOS //; s/Linux //g' /etc/redhat-release | cut -d' ' -f2 | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
  else
    message "Alert" "Operational System not supported!" "clear && exit 1"
  fi

  _TITLE="--backtitle \"Tools Installer - $_APP_NAME | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""

  _RECIPE_FILE="$(pwd)/recipe.ti"
}

tool_check() {
  print_colorful white bold "> Checking for $1..."
  if command -v "$1" > /dev/null; then
    print_colorful white bold "> Detected $1!"
  else
    print_colorful white bold "> Installing $1..."
    $_PACKAGE_COMMAND install -y "$1"
  fi
}

print_colorful () {
  _COLOR=$1
  _STYLE=$2
  _TEXT=$3

  case $_COLOR in
    white)
      _PRINT_COLOR=37
      ;;
    yellow)
      _PRINT_COLOR=33
      ;;
  esac

  case $_STYLE in
    normal)
      _PRINT_STYLE=m
      ;;
    bold)
      _PRINT_STYLE=1m
      ;;
  esac

  echo
  echo -e "\e[${_PRINT_COLOR};${_PRINT_STYLE}${_TEXT}\e[m"
  echo
}

search_applications () {
  sed '/^ *$/d; /^ *#/d' "$_RECIPE_FILE" | cut -d. -f1 | uniq
}

search_app () {
  egrep ^"$1" "$_RECIPE_FILE" | cut -d. -f1 | uniq
}

search_value () {
  _SEARCH_VALUE=$1
  _SEARCH_FILE=$2

  [ -z "$_SEARCH_FILE" ] && _SEARCH_FILE=$_RECIPE_FILE

  grep "$_SEARCH_VALUE" "$_SEARCH_FILE" | cut -d= -f2
}

search_versions () {
  egrep ^"$1" "$_RECIPE_FILE" | cut -d= -f2 | uniq
}

menu () {
  eval dialog "$_TITLE" --stdout --menu \""$1"\" 0 0 0 "$2"
}

input () {
  eval dialog "$_TITLE" --stdout --inputbox \""$1"\" 0 0 \""$2"\"
}

input_field () {
  _INPUT_FIELD=$1
  _INPUT_MESSAGE=$2
  _INPUT_VALUE=$3

  if [ "$(provisioning)" = "manual" ]; then
    eval dialog "$_TITLE" --stdout --inputbox \""$_INPUT_MESSAGE"\" 0 0 \""$_INPUT_VALUE"\"
  else
    if [ "$_INPUT_FIELD" = "[default]" ]; then
      echo "$_INPUT_VALUE"
    else
      search_value "$_INPUT_FIELD"
    fi
  fi
}

message () {
  _MESSAGE_TITLE=$1
  _MESSAGE_TEXT=$2
  _MESSAGE_COMMAND=$3

  if [ "$(provisioning)" = "manual" ]; then
    eval dialog --title \""$_MESSAGE_TITLE"\" --msgbox \""$_MESSAGE_TEXT"\" 0 0

    if [ -z "$_MESSAGE_COMMAND" ]; then
      main
    else
      $_MESSAGE_COMMAND
    fi
  else
    print_colorful yellow bold "> $_MESSAGE_TITLE: $_MESSAGE_TEXT"

    if [ -z "$_MESSAGE_COMMAND" ]; then
      [ "$_MESSAGE_TITLE" != "Notice" ] && exit 1
    else
      _FIND=$(echo "$_MESSAGE_COMMAND" | grep "clear &&")
      if [ -z "$_FIND" ]; then
        $3
      else
        _COMMAND=${_MESSAGE_COMMAND//clear && /}
        $_COMMAND
      fi
    fi
  fi
}

confirm () {
  _CONFIRM_QUESTION=$1
  _CONFIRM_TITLE=$2

  if [ "$(provisioning)" = "manual" ]; then
    if [ -n "$_CONFIRM_TITLE" ]; then
      dialog --title "$_CONFIRM_TITLE" --yesno "$_CONFIRM_QUESTION" 0 0
    else
      dialog --yesno "$_CONFIRM_QUESTION" 0 0
    fi
  else
    print_colorful yellow bold "$_CONFIRM_TITLE"
  fi
}

change_file () {
  _CF_BACKUP=".backup-$(date +"%Y%m%d%H%M%S%N")"
  _CF_OPERATION=$1
  _CF_FILE=$2
  _CF_FROM=$3
  _CF_TO=$4

  case $_CF_OPERATION in
    replace)
      sed -i"$_CF_BACKUP" -e "s|$_CF_FROM|$_CF_TO|g" "$_CF_FILE"
      ;;
    append)
      sed -i"$_CF_BACKUP" -e "/$_CF_FROM/ a $_CF_TO" "$_CF_FILE"
      ;;
    insert)
      sed -i"$_CF_BACKUP" -e "/$_CF_FROM/ i $_CF_TO" "$_CF_FILE"
      ;;
  esac
}

run_as_root () {
  su -c "$1"
}

run_as_user () {
  su - "$1" -c "$2"
}

run_as_postgres () {
  _PG_COMMAND=$1
  _ERROR_FILE="/tmp/.ti.postgresql.error"

  su - postgres -c "$_PG_COMMAND" 2> $_ERROR_FILE

  if [ $? -ne 0 ] && [ -e "$_ERROR_FILE" ]; then
    _ERROR_MESSAGE=$(cat $_ERROR_FILE)
    rm -f $_ERROR_FILE
    [ -n "$_ERROR_MESSAGE" ] && message "Notice" "$_ERROR_MESSAGE"
  fi
}

postgres_version() {
  if [ "$_OS_TYPE" = "deb" ]; then
    _POSTGRESQL_VERSION=$(apt-cache show postgresql | grep Version | head -n 1 | cut -d: -f2 | cut -d+ -f1 | tr -d '[:space:]')
  elif [ "$_OS_TYPE" = "rpm" ]; then
    _POSTGRESQL_VERSION=$(psql -V 2> /dev/null | cut -d' ' -f3)
    _POSTGRESQL_VERSION=${_POSTGRESQL_VERSION:0:3}
  fi

  echo "$_POSTGRESQL_VERSION"
}

postgres_config_path () {
  if [ "$_OS_TYPE" = "deb" ]; then
    echo "/etc/postgresql/$_POSTGRESQL_VERSION/main"
  elif [ "$_OS_TYPE" = "rpm" ]; then
    echo "/var/lib/pgsql/$_POSTGRESQL_VERSION/data"
  fi
}

postgres_add_user () {
  _FIELD1=$1
  _FIELD2=$2

  _PG_USER_NAME=$(input_field "$_FIELD1" "Enter a user name")
  [ $? -eq 1 ] && main
  [ -z "$_PG_USER_NAME" ] && message "Alert" "The user name can not be blank!"

  _PG_USER_PASSWORD=$(input_field "$_FIELD2" "Enter a password for the user $_PG_USER_NAME")
  [ $? -eq 1 ] && main
  [ -z "$_PG_USER_PASSWORD" ] && message "Alert" "The password can not be blank!"

  confirm "Confirm add user $_PG_USER_NAME with password $_PG_USER_PASSWORD?"
  [ $? -eq 1 ] && main

  run_as_postgres "psql -c \"CREATE ROLE $_PG_USER_NAME LOGIN ENCRYPTED PASSWORD '$_PG_USER_PASSWORD' NOINHERIT VALID UNTIL 'infinity';\""

  [ $? -eq 0 ] && message "Notice" "User $_PG_USER_NAME added successfully!"
}

mysql_as_root () {
  _MYSQL_ROOT_PASSWORD=$1
  _MYSQL_COMMAND=$2
  _ERROR_FILE="/tmp/.ti.mysql.error"

  MYSQL_PWD=$_MYSQL_ROOT_PASSWORD mysql -u root -e "$_MYSQL_COMMAND" 2> $_ERROR_FILE

  if [ $? -ne 0 ] && [ -e "$_ERROR_FILE" ]; then
    _ERROR_MESSAGE=$(cat $_ERROR_FILE)
    rm -f $_ERROR_FILE
    [ -n "$_ERROR_MESSAGE" ] && message "Error" "$_ERROR_MESSAGE"
  fi
}

import_database () {
  _DATABASE_TYPE=$1
  _DATABASE_HOST=$2
  _DATABASE_PORT=$3
  _DATABASE_NAME=$4
  _DATABASE_USER=$5
  _DATABASE_PASSWORD=$6
  _DATABASE_FILE=$7

  if [ "$_DATABASE_TYPE" = "mysql" ]; then
    MYSQL_PWD=$_DATABASE_PASSWORD mysql -h "$_DATABASE_HOST" -P "$_DATABASE_PORT" -u "$_DATABASE_USER" "$_DATABASE_NAME" < "$_DATABASE_FILE"
  fi
}

backup_database () {
  _DATABASE_TYPE=$1
  _DATABASE_HOST=$2
  _DATABASE_PORT=$3
  _DATABASE_NAME=$2
  _DATABASE_USER=$3
  _DATABASE_PASSWORD=$4
  _DATABASE_BACKUP_DATE=".backup-$(date +"%Y%m%d%H%M%S%N")"

  if [ "$_DATABASE_TYPE" = "mysql" ]; then
    MYSQL_PWD=$_DATABASE_PASSWORD mysqldump -h "$_DATABASE_HOST" -P "$_DATABASE_PORT" -u "$_DATABASE_USER" "$_DATABASE_NAME" | gzip -9 > "$_DATABASE_NAME$_DATABASE_BACKUP_DATE.sql.gz"
  fi
}

delete_file () {
  [ -e "$1" ] && rm -rf "$1"
}

backup_folder () {
  _BACKUP_FOLDER="/opt/backups"
  _LAST_FOLDER=$(echo "$1" | cut -d/ -f3)

  [ ! -e "$_BACKUP_FOLDER" ] && mkdir -p "$_BACKUP_FOLDER"

  [ -e "$1" ] && mv "$1" "$_BACKUP_FOLDER/$_LAST_FOLDER-$(date +"%Y%m%d%H%M%S%N")"
}

register_service () {
  _REGISTER_SERVICE_NAME=$1

  if [ "$_OS_TYPE" = "deb" ]; then
    update-rc.d "$_REGISTER_SERVICE_NAME" defaults

  elif [ "$_OS_TYPE" = "rpm" ]; then

    if [ "$_OS_RELEASE" -le 6 ]; then
      chkconfig "$_REGISTER_SERVICE_NAME" on
    else
      systemctl enable "$_REGISTER_SERVICE_NAME"
    fi

  fi
}

action_service () {
  _ACTION_SERVICE_NAME=$1
  _ACTION_SERVICE_OPTION=$2

  if [ "$_OS_TYPE" = "deb" ]; then
    service "$_ACTION_SERVICE_NAME" "$_ACTION_SERVICE_OPTION"

  elif [ "$_OS_TYPE" = "rpm" ]; then

    if [ "$_OS_RELEASE" -le 6 ]; then
      service "$_ACTION_SERVICE_NAME" "$_ACTION_SERVICE_OPTION"
    else
      systemctl "$_ACTION_SERVICE_OPTION" "$_ACTION_SERVICE_NAME"
    fi

  fi
}

admin_service () {
  _ADMIN_SERVICE_NAME=$1
  _ADMIN_SERVICE_OPTION=$2

  case $_ADMIN_SERVICE_OPTION in
    register)
      register_service "$_ADMIN_SERVICE_NAME"
      ;;

    start|restart|reload|stop|status)
      action_service "$_ADMIN_SERVICE_NAME" "$_ADMIN_SERVICE_OPTION"
      ;;
  esac
}

get_java_home () {
  _JAVA_VERSION=$1

  if [ -n "$JAVA_HOME" ]; then
    _JAVA_HOME=$JAVA_HOME
  else
    _JAVA_HOME="/usr/lib/jvm/java-$_JAVA_VERSION-openjdk-$_ARCH"
    [ ! -e "$_JAVA_HOME" ] && _JAVA_HOME="/usr/lib/jvm/java-1.$_JAVA_VERSION.0"
    [ ! -e "$_JAVA_HOME" ] && _JAVA_HOME="/usr/lib/jvm/java-$_JAVA_VERSION"
    [ ! -e "$_JAVA_HOME" ] && _JAVA_HOME="/usr/java/oracle-$_JAVA_VERSION"
    [ ! -e "$_JAVA_HOME" ] && _JAVA_HOME="/opt/java-oracle-$_JAVA_VERSION"
  fi

  echo "$_JAVA_HOME"
}

java_check () {
  _VERSION_CHECK=$1
  _JAVA_TMP_FILE="/tmp/.tools.installer.java_version"

  _JAVA_INSTALLED=$(command -v java)
  if [ -z "$_JAVA_INSTALLED" ]; then
    JAVA_HOME=$(get_java_home "$_VERSION_CHECK")
    export JAVA_HOME
    export PATH=$PATH:$JAVA_HOME/bin

    _JAVA_INSTALLED=$(command -v java)
    [ -z "$_JAVA_INSTALLED" ] && message "Alert" "Java $_VERSION_CHECK is not installed!"
  fi

  java -version > $_JAVA_TMP_FILE 2> $_JAVA_TMP_FILE
  _JAVA_VERSION=$(grep version "$_JAVA_TMP_FILE" | cut -d' ' -f3 | cut -d\" -f2)
  _JAVA_MAJOR_VERSION=$(echo "$_JAVA_VERSION" | cut -d. -f1)
  _JAVA_MINOR_VERSION=$(echo "$_JAVA_VERSION" | cut -d. -f2)
  rm $_JAVA_TMP_FILE

  if [ "$_JAVA_MINOR_VERSION" -lt "$_VERSION_CHECK" ]; then
    message "Alert" "You must have Java $_VERSION_CHECK installed!"
  fi
}

jboss_check () {
  _VERSION=$1

  case $_VERSION in
    "4")
      _JBOSS4_DESCRIPTION="JBoss 4.0.1SP1"
      _FILE="/opt/jboss/readme.html"

      [ -e "$_FILE" ] && _SEARCH=$(grep "$_JBOSS4_DESCRIPTION" "$_FILE")

      _MESSAGE="$_JBOSS4_DESCRIPTION is not installed!"
      ;;
  esac

  [ -z "$_SEARCH" ] && message "Error" "$_MESSAGE"
}

disable_selinux () {
  if [ "$_OS_TYPE" = "rpm" ]; then
    _SELINUX_ENABLED=$(grep "^SELINUX=enforcing" /etc/selinux/config)

    if [ -n "$_SELINUX_ENABLED" ]; then
      message "Alert" "$_SELINUX_ENABLED detected. Is changed to SELINUX=permissive"

      change_file "replace" "/etc/selinux/config" "^$_SELINUX_ENABLED" "SELINUX=permissive"
    fi
  fi
}

add_user_to_group () {
  _GROUP=$1
  _SHOW_ALERT=$2
  _USER_LOGGED=$(run_as_root "echo $SUDO_USER")

  _USER=$(input_field "[default]" "Enter the user name to be added to the group $_GROUP" "$_USER_LOGGED")
  [ $? -eq 1 ] && main
  [ -z "$_USER" ] && message "Alert" "The user name can not be blank!"

  _FIND_USER=$(grep "$_USER" /etc/passwd)
  [ -z "$_FIND_USER" ] && message "Alert" "User not found!"

  if [ "$_OS_NAME" = "debian" ]; then
    gpasswd -a "$_USER" "$_GROUP"
  else
    usermod -aG "$_GROUP" "$_USER"
  fi

  if [ "$_SHOW_ALERT" != "[no_alert]" ]; then
    if [ $? -eq 0 ]; then
      message "Notice" "$_USER user was added the $_GROUP group successfully! You need to log out and log in again"
    else
      message "Error" "A problem has occurred in the operation!"
    fi
  fi
}

provisioning () {
  if [ -e "$_RECIPE_FILE" ]; then
    echo "automatic"
  else
    echo "manual"
  fi
}

php_version() {
  case "$_OS_TYPE" in
    deb)
      if [ "$_OS_VERSION" -le 14 ]; then
        apt-cache show ^php[0-9]$ | grep Version | head -n 1 | cut -d' ' -f2 | cut -d+ -f1
      else
        apt-cache show ^php | grep Version | head -n 1 | cut -d' ' -f2 | cut -d- -f1
      fi
      ;;
    rpm)
      yum info php | grep Version | head -n 1 | cut -d: -f2
      ;;
  esac
}