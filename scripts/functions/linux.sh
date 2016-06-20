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
  else
    message "Alert" "Operational System not supported!" "clear && exit 1"
  fi

  _TITLE="--backtitle \"Tools Installer - $_APP_NAME | OS: $_OS_DESCRIPTION | Kernel: $_OS_KERNEL\""

  _RECIPE_FILE="recipe.ti"
}

tool_check() {
  echo "Checking for $1..."
  if command -v $1 > /dev/null; then
    echo "Detected $1!"
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

search_applications () {
  echo $(cat $_RECIPE_FILE | sed '/^ *$/d; /^ *#/d' | cut -d. -f1 | uniq)
}

search_app () {
  echo $(cat $_RECIPE_FILE | egrep ^$1 | cut -d. -f1 | uniq)
}

search_value () {
  echo $(echo $(cat $_RECIPE_FILE | grep $1 | cut -d= -f2))
}

search_versions () {
  echo $(cat $_RECIPE_FILE | egrep ^$1 | cut -d= -f2 | uniq)
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
    echo "> $_MESSAGE_TITLE: $_MESSAGE_TEXT"

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
    echo "$2"
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
  esac
}

run_as_root () {
  su -c "$1"
}

run_as_user () {
  su - $1 -c "$2"
}

mysql_as_root () {
  if [ "$2" = "[no_password]" ]; then
    mysql -h $1 -u root -e "$3" 2> /dev/null
  else
    mysql -h $1 -u root -p$2 -e "$3" 2> /dev/null
  fi
}

delete_file () {
  [ -e "$1" ] && rm -rf $1
}

backup_folder () {
  [ -e "$1" ] && mv "$1" "$1-backup-`date +"%Y%m%d%H%M%S%N"`"
}

register_service () {
  _SERVICE_NAME=$1

  if [ "$_OS_TYPE" = "deb" ]; then
    update-rc.d $_SERVICE_NAME defaults
  elif [ "$_OS_TYPE" = "rpm" ]; then
    chkconfig $_SERVICE_NAME on
  fi
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
