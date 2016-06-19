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

message () {
  eval dialog --title \"$1\" --msgbox \"$2\" 0 0

  if [ -z "$3" ]; then
    main
  else
    $3
  fi
}

confirm () {
  _CONFIRM_QUESTION=$1
  _CONFIRM_TITLE=$2

  if [ ! -z "$_CONFIRM_TITLE" ]; then
    dialog --title "$_CONFIRM_TITLE" --yesno "$1" 0 0
  else
    dialog --yesno "$1" 0 0
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
  [ -e "$1" ] && rm $1
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

disable_selinux () {
  if [ "$_OS_TYPE" = "rpm" ]; then
    _SELINUX_ENABLED=$(cat /etc/selinux/config | grep "^SELINUX=enforcing")

    if [ ! -z "$_SELINUX_ENABLED" ]; then
      dialog --title "$_SELINUX_ENABLED detected. Is changed to SELINUX=permissive" --msgbox "" 0 0

      change_file "replace" "/etc/selinux/config" "^$_SELINUX_ENABLED" "SELINUX=permissive"
    fi
  fi
}
