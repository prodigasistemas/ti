# http://www.thegeekstuff.com/2009/11/unix-sed-tutorial-append-insert-replace-and-count-file-lines/

os_check () {
  _OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
  _OS_KERNEL=$(uname -r)

  if [ $(which lsb_release 2>/dev/null) ]; then
    _OS_TYPE="deb"
    _OS_NAME=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')
    _OS_CODENAME=$(lsb_release -cs)
    _OS_NUMBER=$(lsb_release -rs)
    _OS_DESCRIPTION="$(lsb_release -cds) $_OS_ARCH bits"
    _PACKAGE_COMMAND="apt-get"
  elif [ -e "/etc/redhat-release" ]; then
    _OS_TYPE="rpm"
    _OS_NAME=$(cat /etc/redhat-release | awk '{ print tolower($1) }')
    _OS_RELEASE=$(cat /etc/redhat-release | sed 's/CentOS //; s/Linux //g' | cut -d' ' -f2 | cut -d. -f1)
    _OS_DESCRIPTION="$(cat /etc/redhat-release) $_OS_ARCH bits"
    _PACKAGE_COMMAND="yum"
  else
    message "Alert" "Operational System not supported!" "clear && exit 1"
  fi

  _TITLE="--backtitle \"Tools Installer - $_APP_NAME | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""

  _RECIPE_FILE="$(pwd)/recipe.ti"
}

tool_check() {
  echo
  print_colorful white bold "> Checking for $1..."
  if command -v $1 > /dev/null; then
    print_colorful white bold "> Detected $1!"
  else
    print_colorful white bold "> Installing $1..."
    $_PACKAGE_COMMAND install -y $1
  fi
  echo
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

  echo -e "\e[${_PRINT_COLOR};${_PRINT_STYLE}${_TEXT}\e[m"
}

search_applications () {
  echo $(cat $_RECIPE_FILE | sed '/^ *$/d; /^ *#/d' | cut -d. -f1 | uniq)
}

search_app () {
  echo $(cat $_RECIPE_FILE | egrep ^$1 | cut -d. -f1 | uniq)
}

search_value () {
  _SEARCH_VALUE=$1
  _SEARCH_FILE=$2

  [ -z "$_SEARCH_FILE" ] && _SEARCH_FILE=$_RECIPE_FILE

  echo $(echo $(cat $_SEARCH_FILE | grep $_SEARCH_VALUE | cut -d= -f2))
}

search_versions () {
  echo $(cat $_RECIPE_FILE | egrep ^$1 | cut -d= -f2 | uniq)
}

menu () {
  echo $(eval dialog $_TITLE --stdout --menu \"$1\" 0 0 0 $2)
}

input () {
  echo $(eval dialog $_TITLE --stdout --inputbox \"$1\" 0 0 \"$2\")
}

input_field () {
  _INPUT_FIELD=$1
  _INPUT_MESSAGE=$2
  _INPUT_VALUE=$3

  if [ "$(provisioning)" = "manual" ]; then
    echo $(eval dialog $_TITLE --stdout --inputbox \"$_INPUT_MESSAGE\" 0 0 \"$_INPUT_VALUE\")
  else
    if [ "$_INPUT_FIELD" = "[default]" ]; then
      echo $_INPUT_VALUE
    else
      echo $(search_value $_INPUT_FIELD)
    fi
  fi
}

message () {
  _MESSAGE_TITLE=$1
  _MESSAGE_TEXT=$2
  _MESSAGE_COMMAND=$3

  if [ "$(provisioning)" = "manual" ]; then
    eval dialog --title \"$_MESSAGE_TITLE\" --msgbox \"$_MESSAGE_TEXT\" 0 0

    if [ -z "$_MESSAGE_COMMAND" ]; then
      main
    else
      $_MESSAGE_COMMAND
    fi
  else
    echo
    print_colorful yellow bold "> $_MESSAGE_TITLE: $_MESSAGE_TEXT"
    echo

    if [ -z "$_MESSAGE_COMMAND" ]; then
      [ "$_MESSAGE_TITLE" != "Notice" ] && exit 1
    else
      _FIND=$(echo $_MESSAGE_COMMAND | grep "clear &&")
      if [ -z "$_FIND" ]; then
        $3
      else
        _COMMAND=$(echo $_MESSAGE_COMMAND | sed "s|clear && ||g")
        $_COMMAND
      fi
    fi
  fi
}

confirm () {
  _CONFIRM_QUESTION=$1
  _CONFIRM_TITLE=$2

  if [ "$(provisioning)" = "manual" ]; then
    if [ ! -z "$_CONFIRM_TITLE" ]; then
      dialog --title "$_CONFIRM_TITLE" --yesno "$1" 0 0
    else
      dialog --yesno "$1" 0 0
    fi
  else
    echo
    print_colorful yellow bold "$2"
    echo
  fi
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
    insert)
      sed -i$_CF_BACKUP -e "/$_CF_FROM/ i $_CF_TO" $_CF_FILE
      ;;
  esac
}

run_as_root () {
  su -c "$1"
}

run_as_user () {
  su - $1 -c "$2"
}

run_as_postgres () {
  su - postgres -c "$1" 2> /dev/null
}

postgres_version() {
  [ "$_OS_TYPE" = "deb" ] && _POSTGRESQL_VERSION=$(apt-cache show postgresql | grep Version | head -n 1 | cut -d: -f2 | cut -d+ -f1 | tr -d [:space:])
  if [ "$_OS_TYPE" = "rpm" ]; then
    _POSTGRESQL_VERSION=$(run_as_postgres "psql -V" | cut -d' ' -f3)
    _POSTGRESQL_VERSION=${_POSTGRESQL_VERSION:0:3}
  fi

  echo $_POSTGRESQL_VERSION
}

mysql_as_root () {
  _MYSQL_HOST=$1
  _MYSQL_PORT=$2
  _MYSQL_ROOT_PASSWORD=$3
  _MYSQL_COMMAND=$4

  if [ "$_MYSQL_ROOT_PASSWORD" = "[no_password]" ]; then
    mysql -h $_MYSQL_HOST -P $_MYSQL_PORT -u root -e "$_MYSQL_COMMAND" 2> /dev/null
  else
    mysql -h $_MYSQL_HOST -P $_MYSQL_PORT -u root -p$_MYSQL_ROOT_PASSWORD -e "$_MYSQL_COMMAND" 2> /dev/null
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
    mysql -h $_DATABASE_HOST -P $_DATABASE_PORT -u $_DATABASE_USER -p$_DATABASE_PASSWORD $_DATABASE_NAME < $_DATABASE_FILE
  fi
}

backup_database () {
  _DATABASE_TYPE=$1
  _DATABASE_HOST=$2
  _DATABASE_PORT=$3
  _DATABASE_NAME=$2
  _DATABASE_USER=$3
  _DATABASE_PASSWORD=$4
  _DATABASE_BACKUP_DATE=".backup-`date +"%Y%m%d%H%M%S%N"`"

  if [ "$_DATABASE_TYPE" = "mysql" ]; then
    mysqldump -h $_DATABASE_HOST -P $_DATABASE_PORT -u $_DATABASE_USER -p$_DATABASE_PASSWORD $_DATABASE_NAME | gzip -9 > "$_DATABASE_NAME$_DATABASE_BACKUP_DATE.sql.gz"
  fi
}

delete_file () {
  [ -e "$1" ] && rm -rf $1
}

backup_folder () {
  _BACKUP_FOLDER="/opt/backups"
  _LAST_FOLDER=$(echo $1 | cut -d/ -f3)

  [ ! -e "$_BACKUP_FOLDER" ] && mkdir -p "$_BACKUP_FOLDER"

  [ -e "$1" ] && mv "$1" "$_BACKUP_FOLDER/$_LAST_FOLDER-`date +"%Y%m%d%H%M%S%N"`"
}

register_service () {
  _REGISTER_SERVICE_NAME=$1

  if [ "$_OS_TYPE" = "deb" ]; then
    update-rc.d $_REGISTER_SERVICE_NAME defaults

  elif [ "$_OS_TYPE" = "rpm" ]; then

    if [ "$_OS_RELEASE" -le 6 ]; then
      chkconfig $_REGISTER_SERVICE_NAME on
    else
      systemctl enable $_REGISTER_SERVICE_NAME
    fi

  fi
}

action_service () {
  _ACTION_SERVICE_NAME=$1
  _ACTION_SERVICE_OPTION=$2

  if [ "$_OS_TYPE" = "deb" ]; then
    service $_ACTION_SERVICE_NAME $_ACTION_SERVICE_OPTION

  elif [ "$_OS_TYPE" = "rpm" ]; then

    if [ "$_OS_RELEASE" -le 6 ]; then
      service $_ACTION_SERVICE_NAME $_ACTION_SERVICE_OPTION
    else
      systemctl $_ACTION_SERVICE_OPTION $_ACTION_SERVICE_NAME
    fi

  fi
}

admin_service () {
  _ADMIN_SERVICE_NAME=$1
  _ADMIN_SERVICE_OPTION=$2

  case $_ADMIN_SERVICE_OPTION in
    register)
      register_service $_ADMIN_SERVICE_NAME
      ;;

    start|restart|reload|stop|status)
      action_service $_ADMIN_SERVICE_NAME $_ADMIN_SERVICE_OPTION
      ;;
  esac
}

java_check () {
  _VERSION_CHECK=$1
  _JAVA_TMP_FILE="/tmp/.tools.installer.java_version"

  _JAVA_INSTALLED=$(command -v java)
  [ -z "$_JAVA_INSTALLED" ] && message "Alert" "Java is not installed!"

  java -version 2> $_JAVA_TMP_FILE
  _JAVA_VERSION=$(cat $_JAVA_TMP_FILE | grep version | cut -d' ' -f3 | cut -d\" -f2)
  _JAVA_MAJOR_VERSION=$(echo $_JAVA_VERSION | cut -d. -f1)
  _JAVA_MINOR_VERSION=$(echo $_JAVA_VERSION | cut -d. -f2)
  rm $_JAVA_TMP_FILE

  if [ "$_JAVA_MINOR_VERSION" -lt "$_VERSION_CHECK" ]; then
    message "Alert" "You must have Java $_VERSION_CHECK installed!"
  fi
}

jboss_check () {
  _VERSION=$1

  if [ "$_VERSION" = "4" ]; then
    _JBOSS4_DESCRIPTION="JBoss 4.0.1SP1"
    _FILE="/opt/jboss/readme.html"

    [ -e "$_FILE" ] && _SEARCH=$(cat $_FILE | grep "$_JBOSS4_DESCRIPTION")

    _MESSAGE="$_JBOSS4_DESCRIPTION is not installed!"
  fi

  [ -z "$_SEARCH" ] && message "Error" "$_MESSAGE"
}

disable_selinux () {
  if [ "$_OS_TYPE" = "rpm" ]; then
    _SELINUX_ENABLED=$(cat /etc/selinux/config | grep "^SELINUX=enforcing")

    if [ ! -z "$_SELINUX_ENABLED" ]; then
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

  _FIND_USER=$(cat /etc/passwd | grep $_USER)
  [ -z "$_FIND_USER" ] && message "Alert" "User not found!"

  if [ "$_OS_NAME" = "debian" ]; then
    gpasswd -a $_USER $_GROUP
  else
    usermod -aG $_GROUP $_USER
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
