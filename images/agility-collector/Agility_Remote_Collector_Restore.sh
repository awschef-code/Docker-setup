#!/bin/bash
#
# Copyright (c) 2008-2013 ServiceMesh, Incorporated; All Rights Reserved
# Copyright (c) 2013-Present Computer Sciences Corporation
# ALL SOFTWARE, INFORMATION AND ANY OTHER RELATED COMMUNICATIONS (COLLECTIVELY,
# "WORKS") ARE CONFIDENTIAL AND PROPRIETARY INFORMATION THAT ARE THE EXCLUSIVE
# PROPERTY OF SERVICEMESH.  ALL WORKS ARE PROVIDED UNDER THE APPLICABLE
# AGREEMENT OR END USER LICENSE AGREEMENT IN EFFECT BETWEEN YOU AND
# SERVICEMESH.  UNLESS OTHERWISE SPECIFIED IN THE APPLICABLE AGREEMENT, ALL
# WORKS ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND EITHER EXPRESSED OR
# IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  ALL USE, DISCLOSURE
# AND/OR REPRODUCTION OF WORKS NOT EXPRESSLY AUTHORIZED BY SERVICEMESH IS
# STRICTLY PROHIBITED.
#
# Assumptions:
#     1. the remote collector mysql credentials are the same as Agility Platform
#     2. temporary working directory will be /tmp/migration.  If /tmp does not have enough space, create a symbolic link to another disk
#     3. the remote collector is containerized and the mysql database runs in a separate container
#     4. the mysql container name (dbUrl) will be determined from com.servicemesh.agility.database.cfg
#
# Parameters from remote collector VM:
#    1. ${this.publicAddress}
#    2. ${AgilityManager_DbUser}
#    3. ${AgilityManager_DbPasswd}
#    4. ${Manager.Address}
#    5. $AGILITY_PLATFORM_URL
#    6. $AGILITY_PLATFORM_TOKEN
#

# set a flag to cause an entire pipeline to fail if any part fails
set -o pipefail

# check to see if the root user is running the script. If yes, unset SUDO
uid=`id | sed -e 's;^.*uid=;;' -e 's;\([0-9]\)(.*;\1;'`
if [ "$uid" = "0" ]
then
    # do not set this to space - it will cause issues with tee command
    SUDO=""
else
    SUDO=`which sudo 2>/dev/null`
    if [ -z "$SUDO" ]
    then
        echo "ERROR: sudo not found!"
        exit 10
    fi
fi

SCRIPT_NAME="'Agility_Remote_Collector_Restore'"
AGILITY_HOME="/opt/agility-platform"
TMP_DIR="/tmp/migration"

echo
echo "INFO: running script $SCRIPT_NAME"
echo

# parameters passed in from remote collector VM operational script
IP_ADDRESS="$1"
MYSQL_USER="$2"
MYSQL_PASSWD="$3"
MANAGER_ADDRESS="$4"
PLATFORM_URL="$5"
PLATFORM_TOKEN="$6"

if [[ -z "$MYSQL_USER" ]]
then
    echo "ERROR: mySQL user is missing.  Restore cannot continue."
    exit 15 
fi

if [[ -z "$MYSQL_PASSWD" ]]
then
    echo "ERROR: mySQL password is missing.  Restore cannot continue."
    exit 16 
fi

if [[ -z "$IP_ADDRESS" ]]
then
    echo "ERROR: remote collector IP address is missing.  Restore cannot continue."
    exit 17 
fi

if [[ -z "$MANAGER_ADDRESS" ]]
then
    echo "ERROR: the Agility Platform IP address is missing.  Restore cannot continue."
    exit 18 
fi

if [[ -z "$PLATFORM_URL" ]]
then
    echo "ERROR: the Agility Platform URL is missing.  Restore cannot continue."
    exit 19 
fi

if [[ -z "$PLATFORM_TOKEN" ]]
then
    echo "ERROR: the Agility Platform Token is missing.  Restore cannot continue."
    exit 20 
fi

dbUrl=`grep dbUrl $AGILITY_HOME/etc/com.servicemesh.agility.database.cfg | sed -e "s/.*=//g"`
DB_CONTAINER_NAME=`echo $dbUrl | cut -d':' -f3 | tr -d '\/'`

if [[ -z "$DB_CONTAINER_NAME" ]]
then
    echo "ERROR: the mySQL database container server name could not be determined.  Restore cannot continue."
    exit 25
fi

echo "INFO: operating system release = `uname -r`"
echo "INFO: remote collector IP Address = $IP_ADDRESS"
echo "INFO: Agility Platform IP Address = $MANAGER_ADDRESS"
echo "INFO: mySQL Container Name = $DB_CONTAINER_NAME"

# verify this is a configured remote collector
SQL_STMT="Select sp.id, sp.hostname, i.id, i.template_id, i.state, os.name From VMServiceProvider sp, VMInstance i, VMStack s, VMOperatingSystem os Where sp.type_id = 3 and sp.hostname = i.publicAddress and i.stack_id = s.id and s.operatingSystem_id = os.id and sp.hostname = '"$IP_ADDRESS"'; commit;"

SQL_RESULTS=`mysql --batch -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h $MANAGER_ADDRESS cloud -e "$SQL_STMT" | sed -e 's/\t/,/g'`
CMD_STATUS=$?

if [[ "$CMD_STATUS" -ne "0" ]]
then
     echo "ERROR: the query failed with status code $CMD_STATUS"
     exit 30
fi

if [[ -z "$SQL_RESULTS" ]]
then
    echo "ERROR: server $IP_ADDRESS is not registered as a remote collector with Agiltiy.  Not a valid environment for collector restoration."
    exit 40
fi

# Values from VMState enum
STATES[0]="Unknown"
STATES[1]="Starting"
STATES[2]="Running"
STATES[3]="Paused"
STATES[4]="Stopping"
STATES[5]="Stopped"
STATES[6]="Destroyed"
STATES[7]="Failed"
STATES[8]="Degraded"

# set the field separator to new line save current value so it can be reset
CUR_IFS=$IFS
IFS=$'\n'

# iterate over each row - ignore header
isHeader=1
ROW_CNT=0
for row in $SQL_RESULTS
do
    if [[ $isHeader -eq 1 ]]
    then
        isHeader=0
    else
        ROW_CNT=`expr $ROW_CNT + 1`

        COLLECTOR_ID=`echo "$row" | cut -d',' -f1`
        COLLECTOR_HOSTNAME=`echo "$row" | cut -d',' -f2`
        COLLECTOR_INSTANCE_ID=`echo "$row" | cut -d',' -f3`
        COLLECTOR_TEMPLATE_ID=`echo "$row" | cut -d',' -f4`
        stateId=`echo "$row" | cut -d',' -f5`
        COLLECTOR_STATUS="${STATES[$stateId]}"
        COLLECTOR_OS=`echo "$row" | cut -d',' -f6`
    fi
done

IFS=$CUR_IFS

# should only be one row
if [[ $ROW_CNT -ne 1 ]]
then
    echo "ERROR: more than one collector with IP address $IP_ADDRESS has been registered.  Only one collector was expected.  Restore failed."
    exit 50
fi
echo
echo "INFO: collector information -- "
echo "     ID = $COLLECTOR_ID"
echo "     hostname = $COLLECTOR_HOSTNAME "
echo "     instance ID = $COLLECTOR_INSTANCE_ID"
echo "     template ID = $COLLECTOR_TEMPLATE_ID"
echo "     status = $COLLECTOR_STATUS"
echo "     O/S = $COLLECTOR_OS"
echo

echo "INFO: checking for existence of metric database on collector $IP_ADDRESS."

# make sure there is a metric database
echo "INFO: checking for existence of the metric database on server $DB_CONTAINER_NAME"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h "$DB_CONTAINER_NAME" metric -e "show tables;" >/dev/null 2>&1
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: no metric database found for collector $IP_ADDRESS.  This does not appear to be a valid remote collector.  Restore failed."
    exit 100
fi

echo "INFO: ensure no VM assignments have been made to collector $IP_ADDRESS."

echo "INFO: checking VMs assigned to collector $COLLECTOR_ID."
SQL_STMT="select count(*) from CollectorAssignment where collector_id = $COLLECTOR_ID; commit;"

SQL_RESULTS=`mysql --batch -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h $MANAGER_ADDRESS metric -e "$SQL_STMT" | sed -e 's/\t/,/g'`
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: query failed with status $CMD_STATUS.  Unable to determine if there are assigned VMs.  Restore failed."
    exit 110
fi

# set the field separator to new line save current value so it can be reset
CUR_IFS=$IFS
IFS=$'\n'


# iterate over each row - ignore header
isHeader=1
for row in $SQL_RESULTS
do
    if [[ $isHeader -eq 1 ]]
    then
        isHeader=0
    else
        rowCnt=`echo "$row" | cut -d',' -f1`

        if [[ $rowCnt -gt 0 ]]
        then
            echo "ERROR: multiple assignments [$rowCnt] were found in the CollectorAssignment table.  This implies this is not a fresh remote collector and VMs have been assigned.  Restoration will not occur."
            exit 120
        fi

        echo "INFO: no VMs have been assigned to this collector.  Restoration will continue."
    fi
done

IFS=$CUR_IFS

echo "INFO: collector $COLLECTOR_ID with IP address $IP_ADDRESS is a fresh remote collector and is a candidate for restoration."

# prepare to extract the archive
WORK_DIR="$TMP_DIR/collectorInfo"

# clean up any previous runs
$SUDO rm -rf $WORK_DIR

# check to see if the input archive file exists
ARCHIVE_FILE_SEARCH_TOKEN='collector_*.tgz'

echo "INFO: looking for archive in $TMP_DIR matching $ARCHIVE_FILE_SEARCH_TOKEN"

# change directory to expected location of restore archive file
cd $TMP_DIR

MATCHING_ARCHIVE_CNT=`$SUDO ls $ARCHIVE_FILE_SEARCH_TOKEN | wc -l`

if [[ $MATCHING_ARCHIVE_CNT -eq 0 ]]
then
    echo "ERROR: no files found in $TMP_DIR matching $ARCHIVE_FILE_SEARCH_TOKEN.  Nothing to restore."
    exit 130
fi

if [[ $MATCHING_ARCHIVE_CNT -gt 1 ]]
then
    echo "ERROR: found multiple files [$MATCHING_ARCHIVE_CNT] in $TMP_DIR matching $ARCHIVE_FILE_SEARCH_TOKEN.  Unsafe to continue with restore operation."
    exit 140
fi

ARCHIVE_FILE=`$SUDO ls $ARCHIVE_FILE_SEARCH_TOKEN`
DEPRECATED_COLLECTOR_IP=`echo $ARCHIVE_FILE | cut -d'_' -f2 | cut -d't' -f1 | sed 's/.$//'`

echo "INFO: restoring archive $ARCHIVE_FILE"
echo "INFO: deprecated collector IP Address $DEPRECATED_COLLECTOR_IP"

# extract the archive
$SUDO tar -xzPf $ARCHIVE_FILE
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: the archive extraction failed for $ARCHIVE_FILE.  Restore failed."
    exit 150
fi

FILENAME_ROOT="collector_$DEPRECATED_COLLECTOR_IP"
INFO_FILE="$FILENAME_ROOT.txt"
DUMP_FILE="${FILENAME_ROOT}_mysqldump.sql"

cd $WORK_DIR
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: unable to change directory to $WORK_DIR.  Resotre  failed."
    exit 160
fi

# confirm the expected files are in the working directory, i.e. extracted files
FILE_CNT=`$SUDO ls $INFO_FILE | wc -l`

if [[ $FILE_CNT -ne 1 ]]
then
    echo "ERROR: file $INFO_FILE was not found in directory $WORK_DIR.  The archive extraction is suspect.  Restore failed."
    exit 170
fi

FILE_SIZE=`$SUDO ls -l $INFO_FILE | tr -s ' ' | cut -d' ' -f5`
if [[ $FILE_CNT -le 0 ]]
then
    echo "ERROR: file $INFO_FILE was found in directory $WORK_DIR but had an invalid file size.  The archive extraction is suspect.  Restore failed."
    exit 180
fi

# confirm the expected files are in the working directory, i.e. extracted files
FILE_CNT=`$SUDO ls $DUMP_FILE | wc -l`

if [[ $FILE_CNT -ne 1 ]]
then
    echo "ERROR: file $DUMP_FILE was not found in directory $WORK_DIR.  The archive extraction is suspect.  Restore failed."
    exit 190
fi

FILE_SIZE=`$SUDO ls -l $DUMP_FILE | tr -s ' ' | cut -d' ' -f5`
if [[ $FILE_CNT -le 0 ]]
then
    echo "ERROR: file $DUMP_FILE was found in directory $WORK_DIR but had an invalid file size.  The archive extraction is suspect.  Restore failed."
    exit 200
fi

# extract deprecated collector info
DEPRECATED_COLLECTOR_ID=`cat $INFO_FILE | grep "Collector ID" | cut -d' ' -f4`
DEPRECATED_COLLECTOR_HOSTNAME=`cat $INFO_FILE | grep "Collector hostname" | cut -d' ' -f4`
DEPRECATED_COLLECTOR_TEMPLATE_ID=`cat $INFO_FILE | grep "Collector template ID" | cut -d' ' -f5`
DEPRECATED_COLLECTOR_INSTANCE_ID=`cat $INFO_FILE | grep "Collector instance ID" | cut -d' ' -f5`

# show the VMs that will need updates to the collectd.conf files
echo
startvms=0
while read line
do
    if [[ $startvms -eq 1 ]]
    then
        vmId=`echo "$line" | tr -s ' ' | cut -d' ' -f1`
        vmTemplateId=`echo "$line" | tr -s ' ' | cut -d' ' -f2`
        vmPublicAddress=`echo "$line" | tr -s ' ' | cut -d' ' -f3`

        echo "     ID: $vmId    Templat ID: $vmTemplateId    IP Address: $vmPublicAddress"
    fi

    if [[ "$line" == "===="* ]]
    then
        startvms=1
        echo "INFO: the following VMs will need to have the /etc/collectd.conf files modified --"
    fi
done < $INFO_FILE
echo

echo "INFO: restoring the database from collector $DEPRECATED_IP to collector $IP_ADDRESS.  The database server is $DB_CONTAINER_NAME."
mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h "$DB_CONTAINER_NAME" metric < $DUMP_FILE

CMD_STATUS=$?
if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: restoring the metric database to $DB_CONTAINER_NAME failed with status $CMD_STATUS."
    exit 210
fi

# confirm the metric database was created
echo "INFO: verifying the metric database was created on $DB_CONTAINER_NAME."
mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h "$DB_CONTAINER_NAME" metric -e "show tables;" >/dev/null 2>&1
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: the metric database does not exist on $DB_CONTAINER_NAME.  It appears the database import failed.  Restore failed."
    exit 220
fi
echo "INFO: the metric database was successfully imported."

# check to see if there is data in the CollectorAssignment table for the deprecated collector - it will be updated later
SQL_STMT="select count(*) from CollectorAssignment where collector_id = $DEPRECATED_COLLECTOR_ID; commit;"

SQL_RESULTS=`mysql --batch -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h $MANAGER_ADDRESS metric -e "$SQL_STMT" | sed -e 's/\t/,/g'`
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: query failed with status $CMD_STATUS.  Unable to determine if there are assigned VMs.  Restore failed."
    exit 230
fi

# set the field separator to new line save current value so it can be reset
CUR_IFS=$IFS
IFS=$'\n'


# iterate over each row - ignore header
isHeader=1
for row in $SQL_RESULTS
do
    if [[ $isHeader -eq 1 ]]
    then
        isHeader=0
    else
        ROW_COUNT=`echo "$row" | cut -d',' -f1`

        if [[ $ROW_COUNT -eq 0 ]]
        then
            echo "ERROR: there are no rows in the CollectorAssignment table.  There should be assigned VMs."
            exit 240
        fi
    fi
done

IFS=$CUR_IFS

echo "INFO: $ROW_COUNT VMs were found in the CollectorAssignment table."

# update the CollectorAssignment table and change the collector ID values to the new collector
# this cannot be done with a query since the dockerized mySQL does not allow updates using the MANAGER_ADDRESS as host -
# an API was created to make this update.  the result of the call should be the new collector ID.
RESULTS=`curl -s -k -X POST -HX-Auth-Token:$PLATFORM_TOKEN "$PLATFORM_URL/api/v1.0/metric/collector/reassign/$DEPRECATED_COLLECTOR_ID/$COLLECTOR_ID"`
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
    echo "ERROR: API call to update the collector ID values failed with status $CMD_STATUS.  The metric database is suspect.  Restore failed."
    exit 250
fi

# the result of the API call should be a json string identifying the new collector ID {collectorId : xxx}
PROP_NAME=`echo $RESULTS | tr -d " " | cut -d":" -f1 | tr -d "{" | tr -d '"'`

if [[ "$PROP_NAME" != "collectorId" ]]
then
    echo "ERROR: API call did not return the expected json string.  This implies the API call failed [$RESULTS].  Restore failed."
    exit 255
fi

PROP_VALUE=`echo $RESULTS | tr -d " " | cut -d":" -f2 | tr -d "}"`
if [[ "$PROP_VALUE" != "$COLLECTOR_ID" ]]
then
    echo "ERROR: API call did not return the expected collector ID value in the json string [$RESULTS].  Restore failed."
    exit 260
fi

echo "INFO: collector reassignment was successful."

# flush the CollectorAssignment cache
RESULTS=`curl -s -k -X DELETE -HX-Auth-Token:$PLATFORM_TOKEN "$PLATFORM_URL/api/v1.0/metric/collector/cache"`
CMD_STATUS=$?

if [[ $CMS_STATUS -ne 0 ]]
then
    echo "WARN: the collector assignment cache failed to be cleared with status $CMD_STATUS.  The data import completed successfully."
    echo "$RESULTS"
fi

echo "INFO: collector assignment cache has been cleared."

# provide next steps to user
echo
echo "INFO: next steps --"
echo "     --  For each VM displayed above, run the Agility Monitor Config script"
echo

echo
echo "INFO: script $SCRIPT_NAME completed successfully."
echo
exit 0
