#!/bin/bash

dialog_check ()
{
  echo "Checking for dialog..."
  if command -v dialog > /dev/null; then
    echo "Detected dialog..."
  else
    echo "Installing dialog..."
    apt-get install -q -y dialog
  fi
}

main () {
  dialog_check

  NAME=$(eval dialog --stdout --inputbox \"What\'s your name?:\" 0 0 \"Shell\")

  echo
  echo "Hello, $NAME!"
  echo
}

main