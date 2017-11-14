#!/bin/bash

NGINX=/usr/local/nginx/www
mkdir -p $NGINX

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


#-----------------------------------------
# General
#-----------------------------------------

function checkGeneralEnv() {
    assertVarDefined ARCHIVA_PORT_8080_TCP_ADDR
    assertVarDefined ARCHIVA_PORT_8080_TCP_PORT
}


#-----------------------------------------
# AgilityX
#-----------------------------------------
function checkAgilityXEnv() {

    if [ -z "$AGILITY_X_SETUP" ]
    then
       if [ ! -d "$NGINX/agility-x" ]
       then
           echo "ERROR: AGILITY_X_SETUP env variable not defined, and no $NGINX/agility-x directory found."
           exit 1
       fi
    fi
}

function setupAgilityXFeatures() {
    return
}

function extractAgilityX() {
    if [ -n "$AGILITY_X_SETUP" ]
    then
        #
        # Pull and expand the agility-x zip
        #
        AGILITY_X_DIR="$NGINX/agility-x"
        AGILITY_X_SETUP=`sed "s/AGILITY_VERSION/$AGILITY_VERSION/g" <<<"$AGILITY_X_SETUP"`
        AGILITY_X_URI="http://${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}/repository/${AGILITY_X_SETUP}"

        echo "Pulling $AGILITY_X_URI"
        curl -s -o agility-x.zip $AGILITY_X_URI
        if [ $? -eq 0 ]; then
            if [ -d "$AGILITY_X_DIR" ]
            then
               # already present. replace in case theres a new build.
               rm -rf $AGILITY_X_DIR
            fi
            mkdir $AGILITY_X_DIR
            echo "Expanding agility-x to $AGILITY_X_DIR"
            unzip -q -o agility-x.zip -d $AGILITY_X_DIR
            UNZIP_RC=$?
            rm agility-x.zip

            if [ $UNZIP_RC -gt 1 ]; then
              echo "Unable to unzip agility-x.zip"
              rm -rf $AGILITY_X_DIR
              return 1
            fi

            return 0
        else
            if [ -d "$AGILITY_X_DIR" ]
            then
               echo "Unable to pull the Agility-X zip file. Leaving the current Agility-X files in place."
               return 0
            fi
            echo "Unable to pull the Agility-X zip file"
            rm -rf $AGILITY_X_DIR
            return 1
        fi
    fi
}

##################################################
###################  MAIN ########################
##################################################

checkGeneralEnv
checkAgilityXEnv

until extractAgilityX
do
    sleep 60
done

echo "Cron jobs for nginx-reload and other jobs."
crontab -u nginx /tmp/crontab.tmp
sudo /etc/init.d/cron start

exec $*
