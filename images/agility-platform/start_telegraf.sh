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

# no need to do work if telegraf is not installed
is_installed=`which telegraf`
if [[ -z "$is_installed" ]]
then
    echo "ERROR: the telegraf command is not in the path.  Telegraf will not start."| $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 3
fi

# make sure it is not already running
isTelegrafRunning
if [[ ! -z "$telegraf_pid" ]]
then
    echo "ERROR: telegraf is already running [$telegraf_pid]."| $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 5
fi

AGILITY_HOME="/opt/agility-platform"
AGILITY_ETC="$AGILITY_HOME/etc"
DB_CONFIG_FILE="$AGILITY_ETC/com.servicemesh.agility.database.cfg"

#
# make sure agility starts successfully
#
echo "INFO: wait for Agility Platform to start.  This will take a few minutes." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
sleep 30

RUNNING=0
# Changed this loop to infinitely wait until agility is started. agility might take long time to start.
while [[ $RUNNING -eq 0 ]]
do
    echo "INFO: waiting for Agility to start."| $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log > /dev/null
    sleep 5

    RUNNING=`curl --silent -k https://localhost:8443/agility/api/current/info | grep "<version>" | grep -v grep | wc -l`

    echo "INFO: is Agility running?  $RUNNING" | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log > /dev/null
done

echo "INFO: Agility is running." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log > /dev/null

# telegraf needs some environment variables set which are used in the config file
sql_stmt="select id, template_id from VMInstance where uuid='#APPLIANCE#';"
sql_results=`mysql --batch -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_PORT_3306_TCP_ADDR -P$MYSQL_PORT_3306_TCP_PORT cloud -e "$sql_stmt" | sed -e 's/\t/,/g'`
cmd_status=$?
if [[ "$cmd_status" -ne "0" ]]
then
    echo "ERROR: unable to get appliance attributes because of query failure.  Telegraf will not start." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 40
fi

if [[ -z "$sql_results" ]]
then
    echo "ERROR: unable to get appliance attributes because query returned no data.  Telegraf will not start." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 50
fi

# set the field separator to new line - save current value so it can be reset
CUR_IFS=$IFS
IFS=$'\n'

# iterate over each row - ignore header
isHeader=1
rowCnt=0
for row in $sql_results
do
    if [[ $isHeader -eq 1 ]]
    then
        isHeader=0
    else
        id=`echo "$row" | cut -d',' -f1`
        templateId=`echo "$row" | cut -d',' -f2`
        rowCnt=`expr $rowCnt + 1`
    fi
done

IFS=$CUR_IFS

if [[ $rowCnt -gt 1 ]]
then
    echo "ERROR: multiple appliance records were found.  This is unexpected.  Telegraf will not start." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 60
fi

if [[ -z "$templateId" ]]
then
    echo "ERROR: missing template ID value.  Telegraf will not start."| $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 62
fi

if [[ -z "$id" ]]
then
    echo "ERROR: missing ID value.  Telegraf will not start."| $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 64
fi

#
# TODO - get the value for interval
#
export COLLECTOR_INTERVAL="30s"
export ITEM_IDENTIFIER="$templateId:$id"

hostname=`hostname`
export HOST_IP=`ping $hostname -c1 | grep from | cut -d' ' -f4 | sed -r 's/:/ /g'`

# start telegraf - the command should be in the path - the config file is identified by env variable
telegraf &

RUNNING=0
telegraf_pid=""
LOOPCNT=60
while [[ $RUNNING -eq 0 && $LOOPCNT -gt 0 ]]
do
    echo "INFO: waiting for Telegraf to start."| $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log > /dev/null
    sleep 5

    isTelegrafRunning
    if [[ ! -z "$telegraf_pid" ]]
    then
        RUNNING=1
    fi

    echo "INFO: is Telegraf running?  $RUNNING" | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log > /dev/null

    LOOPCNT=`expr $LOOPCNT - 1`
done

if [ $LOOPCNT -eq 0 ]
then
    echo "ERROR: Telegraf did not start properly." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
    exit 70
fi

echo "INFO: Telegraf has been started in background mode [$TELEGRAF_PID] at `date`." | $SUDO tee -a /opt/telegraf/var/log/telegraf_start.log
exit 0
