#!/bin/bash


# Utilities
#-----------------------------------------
function assertVarDefined() {
    varName=$1
    if [ -z "${!varName}" ] 
    then
       echo "ERROR: $varName env variable not defined"
       exit 1
    fi
}

function showTitle() {
    echo "======== $1 ..."
}


#-----------------------------------------
# General
#-----------------------------------------

function checkGeneralEnv() {
    assertVarDefined AGILITY_HOME
    assertVarDefined ARCHIVA_PORT_8080_TCP_ADDR
    assertVarDefined ARCHIVA_PORT_8080_TCP_PORT
    assertVarDefined MYSQL_USER
    assertVarDefined MYSQL_PASSWORD
}


#-----------------------------------------
# Filesync
#-----------------------------------------
function checkFilesyncEnv() {
    assertVarDefined AGILITY_VERSION
    assertVarDefined FILESYNC_VERSION
    assertVarDefined FILESYNC_SETUP
}

function extractAndSetupFilesync() {
    #
    # Pull and expand filesync tool
    #
    mkdir -p $AGILITY_HOME/filesync
    touch $AGILITY_HOME/filesync/SETUP
    FILESYNC_SETUP=`sed "s/FILESYNC_VERSION/$FILESYNC_VERSION/g" <<<"$FILESYNC_SETUP"`
    for artifact in ${FILESYNC_SETUP}
    do
        FILESYNC_URI="http://${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}/repository/$artifact"
        grep $FILESYNC_URI $AGILITY_HOME/filesync/SETUP
        if [ "$?" -ne "0" ]
        then
            echo "Pulling $FILESYNC_URI"
            curl --fail -s -L -o setup.zip "$FILESYNC_URI"
            if [ $? -eq 0 ]
            then
                unzip -d "${AGILITY_HOME}/filesync" -q -o setup.zip
                if [ $? -ne 0 ] 
                then
                    echo "Unable to unzip setup.zip for file filesync"
                    exit 1
                fi
                chmod 755 "${AGILITY_HOME}/filesync/sync"
                rm -f "${AGILITY_HOME}/filesync/sync-once"
                ln -s "${AGILITY_HOME}/filesync/sync" "${AGILITY_HOME}/filesync/sync-once"
                rm setup.zip
                echo $FILESYNC_URI >> $AGILITY_HOME/filesync/SETUP
            else
                echo "Unable to pull the filesync zip file $FILESYNC_URI"
                exit 1
            fi
        fi
    done
}


##################################################
###################  MAIN ########################
##################################################

showTitle "Validating environment variables"
checkGeneralEnv
checkFilesyncEnv

showTitle "Waiting for Archiva, and MySQL containers to start"
/bin/bash /root/wait_for_service.sh -t 60 ${MYSQL_PORT_3306_TCP_ADDR}:${MYSQL_PORT_3306_TCP_PORT}
/bin/bash /root/wait_for_service.sh -t 60 ${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}

showTitle "Download, extract, and setup filesync"
extractAndSetupFilesync

showTitle "Initialize filesync"
${AGILITY_HOME}/filesync/sync-once init
if [ $? -ne 0 ] 
then
    echo "filesync failed to initialize.  Exiting."
    exit 1
fi

exec $*
