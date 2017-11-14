#!/bin/bash
#

function isTelegrafRunning() {
    telegraf_pid=`ps -ef |grep telegraf | grep -v grep | grep -v defunct|tr -s " " |cut -d' ' -f8,2 |grep telegraf$| cut -d' ' -f1`
}

# set a flag to cause an entire pipeline to fail if any part fails
set -o pipefail

# check to see if the root user is running the script. If yes, unset SUDO
#
uid=`id | sed -e 's;^.*uid=;;' -e 's;\([0-9]\)(.*;\1;'`
if [ "$uid" = "0" ] ; then
  SUDO=" "
else
  SUDO=`which sudo 2>/dev/null`
  if [ -z "$SUDO" ] ; then
    echo "ERROR: sudo not found.  Telegraf will not be started."
    exit 1
  fi
fi

telegraf_pid=''
isTelegrafRunning
if [[ -z "$telegraf_pid" ]]
then
    echo "INFO: telegraf is not running at `date`.  Nothing to stop." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
else
    $SUDO kill -9 $telegraf_pid
    isTelegrafRunning

    if [[ ! -z "$telegraf_pid" ]]
    then    echo "ERROR: Stopping telegraf failed at `date`." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
        exit 10
    fi

    echo "INFO: Telegraf was stopped at `date`." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
fi

exit 0
