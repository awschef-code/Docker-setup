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
#

# set a flag to cause an entire pipeline to fail if any part fails
set -o pipefail

# check to see if the root user is running the script. If yes, unset SUDO
uid=`id | sed -e 's;^.*uid=;;' -e 's;\([0-9]\)(.*;\1;'`
if [ "$uid" = "0" ]
then
    # do not set this to space - it will cause issues with the tee command
    SUDO=""
else
    SUDO=`which sudo 2>/dev/null`
    if [ -z "$SUDO" ]
    then
        echo "ERROR: sudo not found!"
        exit 10
    fi
fi

SCRIPT_NAME="'Agility_Remote_Collector_Preserve'"
AGILITY_HOME="/opt/agility-platform"

echo
echo "INFO: running script $SCRIPT_NAME"
echo

# parameters passed in from remote collector VM operational script
IP_ADDRESS="$1"
MYSQL_USER="$2"
MYSQL_PASSWD="$3"
MANAGER_ADDRESS="$4"

if [[ -z "$MYSQL_USER" ]]
then
    echo "ERROR: mySQL user is missing.  Preserve cannot continue."
    exit 20
fi

if [[ -z "$MYSQL_PASSWD" ]]
then
    echo "ERROR: mySQL password is missing.  Preserve cannot continue."
    exit 21
fi

if [[ -z "$IP_ADDRESS" ]]
then
    echo "ERROR: remote collector IP address is missing.  Preserve cannot continue."
    exit 22
fi

if [[ -z "$MANAGER_ADDRESS" ]]
then
    echo "ERROR: the Agility Platform IP address is missing.  Preserve cannot continue."
    exit 23
fi

dbUrl=`grep dbUrl $AGILITY_HOME/etc/com.servicemesh.agility.database.cfg | sed -e "s/.*=//g"`
DB_CONTAINER_NAME=`echo $dbUrl | cut -d':' -f3 | tr -d '\/'`

if [[ -z "$DB_CONTAINER_NAME" ]]
then
    echo "ERROR: the mySQL database container server name could not be determined.  Preserve cannot continue."
    exit 25
fi

echo "INFO: operating system release = `uname -r`"
echo "INFO: remote collector IP Address = $IP_ADDRESS"
echo "INFO: Agility Platform IP Address = $MANAGER_ADDRESS"
echo "INFO: mySQL Container Name = $DB_CONTAINER_NAME"

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

TMP_DIR="/tmp/migration"
WORK_DIR="$TMP_DIR/collectorInfo"
FILENAME_ROOT="collector_$IP_ADDRESS"

# clean up any previous run
$SUDO rm -rf $WORK_DIR

# only care about the current collector
SQL_STMT="Select sp.id, sp.hostname, i.id, i.template_id, i.state, os.name From VMServiceProvider sp, VMInstance i, VMStack s, VMOperatingSystem os Where sp.type_id = 3 and sp.hostname = i.publicAddress and i.stack_id = s.id and s.operatingSystem_id = os.id and sp.hostname = '"$IP_ADDRESS"'; commit;"

SQL_RESULTS=`mysql --batch -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h $MANAGER_ADDRESS cloud -e "$SQL_STMT" | sed -e 's/\t/,/g'`
CMD_STATUS=$?

if [[ $CMD_STATUS -ne 0 ]]
then
     echo "ERROR: the query failed with status code $CMD_STATUS"
     exit 30
fi

if [[ ! -z "$SQL_RESULTS" ]]
then
    # create a place to store the info file and DB dump
    $SUDO mkdir -p $WORK_DIR

    INFO_FILE="${WORK_DIR}/${FILENAME_ROOT}.txt"
    $SUDO touch $INFO_FILE
    $SUDO chmod -R 777 $WORK_DIR

    echo "Date: `date`" | $SUDO tee -a $INFO_FILE >/dev/null

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

            collectorId=`echo "$row" | cut -d',' -f1`
            collectorHostname=`echo "$row" | cut -d',' -f2`
            collectorInstanceId=`echo "$row" | cut -d',' -f3`
            collectorTemplateId=`echo "$row" | cut -d',' -f4`
            stateId=`echo "$row" | cut -d',' -f5`
            collectorStatus="${STATES[$stateId]}"
            collectorOS=`echo "$row" | cut -d',' -f6`

            echo "Collector ID = $collectorId" | $SUDO tee -a $INFO_FILE > /dev/null
            echo "Collector hostname = $collectorHostname" | $SUDO tee -a $INFO_FILE > /dev/null
            echo "Collector template ID = $collectorTemplateId" | $SUDO tee -a $INFO_FILE > /dev/null
            echo "Collector instance ID = $collectorInstanceId" | $SUDO tee -a $INFO_FILE > /dev/null
            echo "Collector status = $collectorStatus" | $SUDO tee -a $INFO_FILE > /dev/null
            echo "Collector O/S = $collectorOS" | $SUDO tee -a $INFO_FILE > /dev/null
        fi
    done

    IFS=$CUR_IFS

    # there should only be one row
    if [[ $ROW_CNT -ne 1 ]]
    then
        echo "ERROR: multiple collector rows were found for IP $IP_ADDRESS.  The server should only be registered once.  No work will be done."
        exit 40
    fi

    # find all VMs that have been associated with this collector - if no VMs have been assigned, no work needs to be done
    SQL_STMT="Select instance_id, template_id From CollectorAssignment Where collector_id = ${collectorId}; commit;"

    SQL_RESULTS=`mysql --batch -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h $MANAGER_ADDRESS metric -e "$SQL_STMT" | sed -e 's/\t/,/g'`
    CMD_STATUS=$?

    if [[ $CMD_STATUS -ne 0 ]]
    then
         echo "ERROR: the query failed with status code $CMD_STATUS"
         exit 50
    fi

    if [[ ! -z "$SQL_RESULTS" ]]
    then
        echo "ID             Template ID                  Public Address                Status              Instance ID                                      Name                                     Description" | $SUDO tee -a $INFO_FILE > /dev/null
        echo "==================================================================================================================" | $SUDO tee -a $INFO_FILE > /dev/null

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

                vmInstanceId=`echo "$row" | cut -d',' -f1`
                vmTemplateId=`echo "$row" | cut -d',' -f2`

                # get instance details
                SQL_STMT_INST="Select id, uuid, name, description, instanceId, publicAddress, state, template_id From VMInstance Where id = ${vmInstanceId}; commit;"

                SQL_RESULTS_INST=`mysql --batch -u"$MYSQL_USER" -p"$MYSQL_PASSWD"  -h $MANAGER_ADDRESS cloud -e "$SQL_STMT_INST" | sed -e 's/\t/,/g'`
                CMD_STATUS=$?

                if [[ $CMD_STATUS -ne 0 ]]
                then
                    echo "ERROR: the query failed with status code $CMD_STATUS"
                    exit 60
                fi

                if [[ ! -z "$SQL_RESULTS_INST" ]]
                then
                    isHeaderInst=1
                    for instRow in $SQL_RESULTS_INST
                    do
                        if [[ $isHeaderInst -eq 1 ]]
                        then
                            isHeaderInst=0
                        else
                            vmId=`echo "$instRow" | cut -d',' -f1`
                            vmUuid=`echo "$instRow" | cut -d',' -f2`
                            vmName=`echo "$instRow" | cut -d',' -f3`
                            vmDescription=`echo "$instRow" | cut -d',' -f4`
                            vmInstanceIdentifier=`echo "$instRow" | cut -d',' -f5`
                            vmPublicAddress=`echo "$instRow" | cut -d',' -f6`
                            vmState=`echo "$instRow" | cut -d',' -f7`
                            vmStatus="${STATES[$vmState]}"
                            vmTemplateId=`echo "$instRow" | cut -d',' -f8`

                            echo "$vmId            $vmTemplateId            $vmPublicAddress        $vmStatus     $vmInstanceIdentifier                       $vmName                              $vmDescription" | $SUDO tee -a $INFO_FILE > /dev/null
                        fi
                    done
                else
                    echo "WARN: instance with ID ${vmInstanceId} was not found."
                fi
            fi
        done

        IFS=$CUR_IFS

        # data exists so a backup is required - flush tables and run mysqldump
        mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h "$DB_CONTAINER_NAME" -e "FLUSH TABLES;"

        DUMP_FILE=${WORK_DIR}/${FILENAME_ROOT}_mysqldump.sql

        # only save the metric database
        echo "INFO: backing up the metric database from server $DB_CONTAINER_NAME"
        MYSQLDUMP_BASE_OPTS=" --add-drop-database --max_allowed_packet=24M --single-transaction --quick --routines --triggers --events metric --set-gtid-purged=OFF "
        $SUDO mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWD" -h "$DB_CONTAINER_NAME" $MYSQLDUMP_BASE_OPTS > $DUMP_FILE
        CMD_STATUS=$?

        if [[ $CMD_STATUS -ne 0 ]]
        then
            echo "ERROR: the database backup failed with status $CMD_STATUS"
            exit 70
        else
            REPO_PKG_FILE="$TMP_DIR/${FILENAME_ROOT}.tgz"

            $SUDO tar -czPf ${REPO_PKG_FILE}  ${WORK_DIR}
            CMD_STATUS=$?

            if [[ $CMD_STATUS -ne 0 ]]
            then
                echo "ERROR: the tar command failed with status $CMD_STATUS"
                exit 80
            fi

            # make sure the file exists and has size
            if [[ ! -s "$REPO_PKG_FILE" ]]
            then
                echo "ERROR: the data archive file $REPO_PKG_FILE does not exist."
                exit 90
            fi

            # check the contents of the archive - make sure the two files exist and have size
            INFO_FILE_RESULTS=`tar -tvzPf $REPO_PKG_FILE |grep $INFO_FILE | tr -s ' ' | cut -d' ' -f3`

            if [[ -z "$INFO_FILE_RESULTS" ]]
            then
                echo "ERROR: the data file $INFO_FILE is not incuded in the $REPO_PKG_FILE archive."
                exit 100
            fi

            if [[ $INFO_FILE_RESULTS -le 0 ]]
            then
                echo "ERROR: the data file $INFO_FILE is incuded in the $REPO_PKG_FILE archive; however, it has an invalid size."
                exit 110
            fi

            DUMP_FILE_RESULTS=`tar -tvzPf $REPO_PKG_FILE |grep $DUMP_FILE | tr -s ' ' | cut -d' ' -f3`

            if [[ -z "$DUMP_FILE_RESULTS" ]]
            then
                echo "ERROR: the data file $DUMP_FILE is not incuded in the $REPO_PKG_FILE archive."
                exit 120
            fi

            if [[ $DUMP_FILE_RESULTS -le 0 ]]
            then
                echo "ERROR: the data file $DUMP_FILE is incuded in the $REPO_PKG_FILE archive; however, it has an invalid size."
                exit 130
            fi

            echo
            echo "INFO: the archive $REPO_PKG_FILE has been successfully created.  Save the file to another server so it can be used to restore the collector contents."
            echo
            echo "INFO: begin contents of file $INFO_FILE --"
            cat $INFO_FILE
            echo "INFO: end contents of file $INFO_FILE --"
            echo
            echo "INFO: next steps --"
            echo "     1.  The archive $REPO_PKG_FILE has been successfully created.  Save this file to another server so it can be used to restore the collector contents."
            echo "     2.  Connect to each of the VMs assigned to this collector and stop the collectd service."
            echo "     3.  Destroy this collector ($IP_ADDRESS)."
            echo "     4.  Provision a new remote collector on the same network as this collector."
            echo "     5.  Copy the saved archive to the new collector."
            echo "     6.  Run the Agility Collector Restore script on the new collector."
            echo "     7.  Connect to each VM listed in the file $INFO_FILE and run the Agility Monitor Config script.  This will properly reconfigure the collectd.conf file and restart the collectd service."
            echo   
        fi
    else
        echo "WARN: there are no VMs assigned to this collector.  No work will be done."
    fi
else
    echo "WARN: server $IP_ADDRESS is not a remote collector.  No work will be done."
fi

echo
echo "INFO: script $SCRIPT_NAME completed successfully."
echo
exit 0
