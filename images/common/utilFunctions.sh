#!/bin/bash/

function printLogMessage() {
    echo "`date '+%m/%d/%y %H:%M:%S'` :: $1"
}

function printErrorMessage() {
    printLogMessage "ERROR: $1"
}

function getTasksWithGetent() {
  taskName=$1

  echo $(getent hosts tasks.$taskName | awk '{ print $1 }' | sort -n -t "." -k4)
}

function format_address()
{
    __format_address_result__="$(printf "%03d%03d%03d%03d" $(echo $1 | tr '.' ' '))"
}
