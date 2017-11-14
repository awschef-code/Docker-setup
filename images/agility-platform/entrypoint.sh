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

function determineMysqlHost() {
    # Test compatible with swarm mode. There should be only one instance of
    # mysql-router
    MYSQL_HOST="${MYSQL_PORT_3306_TCP_ADDR:-mysql-router}"
}

function writeDatabaseCfg() {
    DB_CFG_FNAME=/opt/agility-platform/etc/com.servicemesh.agility.database.cfg

    echo "# Generated file -- DO NOT EDIT." > "$DB_CFG_FNAME"
    echo  >> "$DB_CFG_FNAME"
    echo "# the DB URL does not include the database name - it will be added dynamically"  >> "$DB_CFG_FNAME"

    if [[ ! -z "$USE_MYSQL_DEFAULT_DRIVER" && "$USE_MYSQL_DEFAULT_DRIVER" == "true" ]]
    then
        echo "dbDriver=com.mysql.jdbc.Driver"  >> "$DB_CFG_FNAME"
        echo "dbUrl=jdbc:mysql://$MYSQL_HOST:$MYSQL_PORT_3306_TCP_PORT/" >> "$DB_CFG_FNAME"
    else
        echo "dbDriver=com.mysql.jdbc.ReplicationDriver"  >> "$DB_CFG_FNAME"
        echo "dbProps=useSSL=false&readFromMasterWhenNoSlaves=true&allowSlaveDownConnections=true" >> "$DB_CFG_FNAME"
        echo "dbUrl=jdbc:mysql:replication://$MYSQL_HOST:$MYSQL_PORT_3306_TCP_PORT,$MYSQL_HOST:$MYSQL_READ_PORT_3306_TCP_PORT/" >> "$DB_CFG_FNAME"
    fi

    echo "dbUser=$MYSQL_USER" >> "$DB_CFG_FNAME"
    echo "dbPasswd=$MYSQL_PASSWORD" >> "$DB_CFG_FNAME"
    echo  >> "$DB_CFG_FNAME"
    echo "# the packet value must be consistent between master, slave, and mysqldump" >> "$DB_CFG_FNAME"
    echo "max_allowed_packet=16M" >> "$DB_CFG_FNAME"
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
# Agility primary
#-----------------------------------------
SETUP_SCRIPT_DIR_AGILITY=/tmp/agility-$AGILITY_VERSION

function checkAgilityEnv() {
    assertVarDefined AGILITY_VERSION
    assertVarDefined AGILITY_FEATURES
    assertVarDefined AGILITY_SETUP
}

function setupAgilityFeatures() {
    AGILITY_REPO_SUB="s/AGILITY_VERSION/${AGILITY_VERSION}/g"
    AGILITY_FEATURE_SUB="s/AGILITY_FEATURES/${AGILITY_FEATURES}/g"
    sed -i -e "$AGILITY_REPO_SUB" -e "$AGILITY_FEATURE_SUB" etc/org.apache.karaf.features.cfg
}

function extractAgility() {
    #
    # Pull and expand required setup artifacts
    #
    touch $AGILITY_HOME/AGILITY_SETUP
    AGILITY_SETUP=`sed "s/AGILITY_VERSION/$AGILITY_VERSION/g" <<<"$AGILITY_SETUP"`
    for artifact in ${AGILITY_SETUP}
    do
        URI="http://${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}/repository/$artifact"
        grep $URI $AGILITY_HOME/AGILITY_SETUP
        if [ "$?" -ne "0" ]
        then
            echo "Pulling $URI"
            curl --fail -s -o setup.zip "$URI"
            if [ $? -eq 0 ]
            then
                unzip -q -o setup.zip
                if [ $? -ne 0 ]
                then
                    echo "Failed to unzip agility ZIP file"
                    exit 1
                fi
                mkdir -p "${SETUP_SCRIPT_DIR_AGILITY}"
                rm -f "${SETUP_SCRIPT_DIR_AGILITY}/URI"
                rm -f "${SETUP_SCRIPT_DIR_AGILITY}/setup.sh"
                if [ -e setup.sh ]
                then
                    mv setup.sh "${SETUP_SCRIPT_DIR_AGILITY}"
                fi
                echo "$URI" > "${SETUP_SCRIPT_DIR_AGILITY}/URI"
                rm setup.zip
            else
                if [[ ! -z "$NOT_PRODUCTION" && "$NOT_PRODUCTION" == "true" ]]
                then
                    echo "$URI" >  "$AGILITY_HOME/AGILITY_SETUP"
                fi
            fi
        fi
    done
}

function setupAgility() {
    if [[ ! -z "$NOT_PRODUCTION" && "$NOT_PRODUCTION" == "true" ]]
    then
        return
    fi

    #
    # execute and require setup artifacts
    #
    if [ ! -e "${SETUP_SCRIPT_DIR_AGILITY}/URI" ]
    then
        echo "Extraction artifact file of agility ${SETUP_SCRIPT_DIR_AGILITY}/URI not found. Exiting."
        exit 1
    fi

    touch $AGILITY_HOME/AGILITY_SETUP
    URI=$(cat "${SETUP_SCRIPT_DIR_AGILITY}/URI")
    grep $URI $AGILITY_HOME/AGILITY_SETUP
    if [ "$?" -ne "0" ]
    then
        if [ -e "${SETUP_SCRIPT_DIR_AGILITY}/setup.sh" ]
        then
            mv  "${SETUP_SCRIPT_DIR_AGILITY}/setup.sh" $AGILITY_HOME
            /bin/bash ./setup.sh
            if [ "$?" -ne "0" ]
            then
                exit -1
            fi
            rm -f ./setup.sh
        fi
        echo $URI >> $AGILITY_HOME/AGILITY_SETUP
    fi
}

#-----------------------------------------
# Cloud Plugin
#-----------------------------------------
SETUP_SCRIPT_DIR_CLOUD_PLUGIN=/tmp/cloudplugin-$CLOUD_PLUGIN_VERSION

function checkCloudPluginEnv() {

    if [ -n "$CLOUD_PLUGIN_VERSION" ]
    then

        assertVarDefined CLOUD_PLUGIN_FEATURES

#        assertVarDefined CLOUD_PLUGIN_SETUP
    fi
}

function setupCloudPluginFeatures() {
    if [ -n "$CLOUD_PLUGIN_VERSION" ]
    then
        CLOUD_PLUGIN_REPO_SUB="s/CLOUD_PLUGIN_VERSION/${CLOUD_PLUGIN_VERSION}/g"
        CLOUD_PLUGIN_FEATURE_SUB="s/CLOUD_PLUGIN_FEATURES/${CLOUD_PLUGIN_FEATURES}/g"
        sed -i -e "$CLOUD_PLUGIN_REPO_SUB" -e "$CLOUD_PLUGIN_FEATURE_SUB" etc/org.apache.karaf.features.cfg
    else
        # Remove repo and feature entry for cloud-plugin
        sed -i -e "s#,mvn:com.servicemesh/com.servicemesh.agility.cloud-plugin.package/CLOUD_PLUGIN_VERSION/xml##" etc/org.apache.karaf.features.cfg
        sed -i -e "s#,CLOUD_PLUGIN_FEATURES##" etc/org.apache.karaf.features.cfg
    fi
}

function extractDiagnostics() {
    #
    # Pull and expand/execute and require setup artifacts
    #
    touch $AGILITY_HOME/bin

    URI="http://${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}/repository/agility/com/servicemesh/agility-platform/${AGILITY_VERSION}/agility-cli-${AGILITY_VERSION}.tar.gz"

    echo "Pulling Diagnostics from $URI"

    curl --fail -L -s -o diagnostic.tar.gz "$URI"
    if [ $? -eq 0 ]
    then
        tar -xz --file=diagnostic.tar.gz diagnostics
        mv diagnostics $AGILITY_HOME/bin
        tar -xz --file=diagnostic.tar.gz func/supportPub.key
        mkdir $AGILITY_HOME/bin/func
        mv func/supportPub.key $AGILITY_HOME/bin/func/
        if [ $? -ne 0 ]
        then
            echo "Failed to extract diagnostic tar file"
            exit 1
        fi
        rm diagnostic.tar.gz
    fi
}

function extractCloudPlugin() {
    if [ -z "$CLOUD_PLUGIN_SETUP" ]
    then
        return
    fi

    if [ -z "$CLOUD_PLUGIN_VERSION" ]
    then
        return
    fi

    #
    # Pull and expand/execute and require setup artifacts
    #
    touch $AGILITY_HOME/CLOUD_PLUGIN_SETUP
    CLOUD_PLUGIN_SETUP=`sed "s/CLOUD_PLUGIN_VERSION/$CLOUD_PLUGIN_VERSION/g" <<<"$CLOUD_PLUGIN_SETUP"`
    for artifact in ${CLOUD_PLUGIN_SETUP}
    do
        URI="http://${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}/repository/$artifact"
        grep $URI $AGILITY_HOME/CLOUD_PLUGIN_SETUP
        if [ "$?" -ne "0" ]
        then
            echo "Pulling $URI"
            curl --fail -L -s -o setup.zip "$URI"
            if [ $? -eq 0 ]
            then
                unzip -q -o setup.zip
                if [ $? -ne 0 ]
                then
                    echo "Failed to unzip cloud-plugin ZIP file"
                    exit 1
                fi
                mkdir -p "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}"
                rm -f "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/URI"
                if [ -e setup.sh ]
                then
                    rm -f "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/setup.sh"
                    mv setup.sh "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}"
                fi
                echo "$URI" > "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/URI"
                rm setup.zip
            fi
        fi
    done
}

function setupCloudPlugin() {
    if [ -z "$CLOUD_PLUGIN_SETUP" ]
    then
        return
    fi
    if [ -z "$CLOUD_PLUGIN_VERSION" ]
    then
        return
    fi

    #
    # execute and require setup artifacts
    #
    if [ ! -e "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/URI" ]
    then
        echo "Extraction artifact file of cloudplugin ${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/URI not found. Exiting."
        exit 1
    fi

    touch $AGILITY_HOME/CLOUD_PLUGIN_SETUP
    URI=$(cat "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/URI")
    grep $URI $AGILITY_HOME/CLOUD_PLUGIN_SETUP
    if [ "$?" -ne "0" ]
    then
        if [ -e "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/setup.sh" ]
        then
            mv  "${SETUP_SCRIPT_DIR_CLOUD_PLUGIN}/setup.sh" $AGILITY_HOME
            /bin/bash ./setup.sh
            if [ "$?" -ne "0" ]
            then
                exit -1
            fi
            rm -f ./setup.sh
        fi
        echo $URI >> $AGILITY_HOME/CLOUD_PLUGIN_SETUP
    fi
}

function loadEtcFiles() { #copies all the default etc files into the etc directory
   mkdir ${AGILITY_HOME}/etc-backup
   for f in ${AGILITY_HOME}/etc-defaults/* ${AGILITY_HOME}/etc-defaults/.[^.]*
   do
      filename=${f##*/}
      if grep -Fxq $filename noreplacefiles.txt
      then
         ls ${AGILITY_HOME}/etc/$filename > /dev/null 2>&1
         if [[ $? -eq 0 ]]
         then
            echo "A file named $filename already exists in $AGILITY_HOME/etc/. Not overwriting the existing file."
         else
            echo "Copying $filename to $AGILITY_HOME/etc/."
            cp -p $f ${AGILITY_HOME}/etc/$filename
         fi
      else
         ls ${AGILITY_HOME}/etc/$filename > /dev/null 2>&1
         if [[ $? -eq 0 ]]
         then
            echo "A file named $filename already exists in $AGILITY_HOME/etc/. It will be backed up in $AGILITY_HOME/etc-backup and replaced with $f."
            cp -p ${AGILITY_HOME}/etc/$filename ${AGILITY_HOME}/etc-backup/$filename
            cp -p $f ${AGILITY_HOME}/etc/$filename
         else
            echo "Copying $filename to $AGILITY_HOME/etc/."
            cp -p $f ${AGILITY_HOME}/etc/$filename
         fi
      fi
   done
}

function waitForMYSQL() {
   /bin/bash /opt/agility-platform/wait_for_service.sh -t 3000 ${MYSQL_PORT_3306_TCP_ADDR}:${MYSQL_PORT_3306_TCP_PORT}

   if [ $? -ne 0 ]
   then
    echo "Unable to communicate with mysql in the time allowed.  Exiting..."
    exit 1
   fi
}

function waitForArchiva() {
   /bin/bash /opt/agility-platform/wait_for_service.sh -t 1800 ${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}

   if [ $? -ne 0 ]
   then
    echo "Unable to communicate with archiva in the time allowed.  Exiting..."
    exit 1
   fi
}

function waitForZookeeper() {
   /bin/bash /opt/agility-platform/wait_for_service.sh -t 1800 ${ZOOKEEPER_PORT_2181_TCP_ADDR}:${ZOOKEEPER_PORT_2181_TCP_PORT}

   if [ $? -ne 0 ]
   then
    echo "Unable to communicate with zookeeper in the time allowed.  Exiting..."
    exit 1
   fi
}

function waitForRabbit() {
   /bin/bash /opt/agility-platform/wait_for_service.sh -t 1800 ${RABBITMQ_PORT_5672_TCP_ADDR}:${RABBITMQ_PORT_5672_TCP_PORT}

   if [ $? -ne 0 ]
   then
    echo "Unable to communicate with rabbitmq in the time allowed.  Exiting..."
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

# Set permissions on the mounted docker socket
sudo chown smadmin /var/run/docker.sock

if [ -n "$IMPORT_MODE" ]
then
   showTitle "Starting in import mode"
   sudo chown -R smadmin:smadmin ${AGILITY_HOME}/etc
   sudo chown -R smadmin:smadmin /var/spool/agility
   showTitle "Copying default config files into the $AGILITY_HOME/etc directory."
   loadEtcFiles
   showTitle "Validating environment variables"
   checkGeneralEnv
   checkAgilityEnv
   determineMysqlHost

   showTitle "Configuring boot features"
   setupAgilityFeatures

   showTitle "Archiva, and MySQL containers to start"
   waitForMYSQL
   waitForArchiva
   waitForZookeeper
   waitForRabbit

   showTitle "Configure database settings"
   writeDatabaseCfg

   showTitle "Download and extract extensions"
   extractAgility

   showTitle "Download and extract diagnostics"
   extractDiagnostics

   showTitle "Setup extensions"
   setupAgility

   echo "DONE" > /tmp/import.txt
   showTitle "Import mode setup completed"
   exec tail -f /dev/null
else
   showTitle "Copying default config files into the $AGILITY_HOME/etc directory."
   loadEtcFiles
   showTitle "Validating environment variables"
   checkGeneralEnv
   checkFilesyncEnv
   checkAgilityEnv
   checkCloudPluginEnv
   determineMysqlHost

   showTitle "Configuring boot features"
   setupAgilityFeatures
   setupCloudPluginFeatures

   showTitle "Waiting for Zookeeper, RabbitMQ, Archiva, and MySQL containers to start"
   waitForZookeeper
   waitForRabbit
   waitForMYSQL
   waitForArchiva

   showTitle "Download, extract, and setup filesync"
   extractAndSetupFilesync

   showTitle "Configure database settings"
   writeDatabaseCfg

   showTitle "Download and extract extensions"
   extractAgility
   extractCloudPlugin

   showTitle "Download and extract diagnostics"
   extractDiagnostics

   showTitle "Setup extensions"
   setupAgility
   showTitle "Setup Cloud Plugin"
   setupCloudPlugin

   showTitle "Initializing filesync"
   ${AGILITY_HOME}/filesync/sync-once init
   if [ $? -ne 0 ]
   then
    echo "filesync failed to initialize.  Exiting."
    exit 1
   fi

   showTitle "Launching filesync daemon"
   ${AGILITY_HOME}/filesync/sync sync &

   # start telegraf - this is a shell script that will wait for Agility to start, then start telegraf
   showTitle "Launching telegraf daemon"
   start_telegraf.sh &

   showTitle "Starting Agility"
   exec $*
fi
