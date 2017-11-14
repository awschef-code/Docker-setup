#!/bin/bash

function assertVarDefined() {
    varName=$1
    if [ -z "${!varName}" ]
    then
       echo "ERROR: $varName env variable not defined"
       exit 1
    fi
}

#-----------------------------------------
# Filesync
#-----------------------------------------
function checkFilesyncEnv() {
    assertVarDefined FILESYNC_VERSION
    assertVarDefined FILESYNC_SETUP
}

function extractAndSetupFilesync() {
    #
    # Pull and expand filesync tool
    #
    echo "Installing filesync on the container.."
    mkdir -p $AGILITY_HOME/filesync
    touch $AGILITY_HOME/filesync/SETUP
    FILESYNC_SETUP=`sed "s/FILESYNC_VERSION/$FILESYNC_VERSION/g" <<<"$FILESYNC_SETUP"`
    for artifact in ${FILESYNC_SETUP}
    do
        FILESYNC_URI="http://${ARCHIVA_ADDR}:${ARCHIVA_PORT}/$artifact"
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
        echo "Completed Installing filesync"
    done
}

## Installing filesync
checkFilesyncEnv
extractAndSetupFilesync
