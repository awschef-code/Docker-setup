#!/bin/bash

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

function checkCollectorEnv() {
    assertVarDefined COLLECTOR_VERSION
    assertVarDefined COLLECTOR_FEATURE
    assertVarDefined AGILITY_COLLECTOR_SETUP
    assertVarDefined MYSQL_PORT_3306_TCP_ADDR
    assertVarDefined MYSQL_PORT_3306_TCP_PORT
    assertVarDefined MYSQL_USER
    assertVarDefined MYSQL_PASSWORD
    assertVarDefined ARCHIVA_PORT_8080_TCP_ADDR
    assertVarDefined ARCHIVA_PORT_8080_TCP_PORT
    assertVarDefined AGILITY_API_URL
    assertVarDefined API_USER
    assertVarDefined INSTANCE_UUID
}

SETUP_SCRIPT_DIR_AGILITY_COLLECTOR=/tmp/agility-collector-$AGILITY_VERSION

function setupCollectorFeatures() {
    COLLECTOR_REPO_SUB="s/AGILITY_VERSION/${COLLECTOR_VERSION}/g"
    COLLECTOR_FEATURE_SUB="s/AGILITY_FEATURES/${COLLECTOR_FEATURE}/g"
    sed -i -e "$COLLECTOR_REPO_SUB" -e "$COLLECTOR_FEATURE_SUB" etc/org.apache.karaf.features.cfg

    sed -i -e "s#,mvn:com.servicemesh/com.servicemesh.agility.cloud-plugin.package/CLOUD_PLUGIN_VERSION/xml##" etc/org.apache.karaf.features.cfg
    sed -i -e "s#,CLOUD_PLUGIN_FEATURES##" etc/org.apache.karaf.features.cfg
}

function extractAgilityCollector() {
    #
    # Pull and expand required setup artifacts
    #
    touch $AGILITY_HOME/AGILITY_COLLECTOR_SETUP
    AGILITY_COLLECTOR_SETUP=`sed "s/COLLECTOR_VERSION/$COLLECTOR_VERSION/g" <<<"$AGILITY_COLLECTOR_SETUP"`
    for artifact in ${AGILITY_COLLECTOR_SETUP}
    do
        URI="http://${ARCHIVA_PORT_8080_TCP_ADDR}:${ARCHIVA_PORT_8080_TCP_PORT}/repository/$artifact"
        grep $URI $AGILITY_HOME/AGILITY_COLLECTOR_SETUP
        if [ "$?" -ne "0" ]
        then
            echo "Pulling $URI"
            curl --fail -s -o setup.zip "$URI"
            if [ $? -eq 0 ]
            then
                unzip -q -o setup.zip
                if [ $? -ne 0 ]
                then
                    echo "Failed to unzip agility collector ZIP file"
                    exit 1
                fi
                mkdir -p "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}"
                rm -f "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/URI"
                rm -f "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/setup.sh"
                if [ -e setup.sh ]
                then
                    mv setup.sh "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}"
                fi
                echo "$URI" > "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/URI"
                rm setup.zip
            fi
        fi
    done
}

function setupAgilityCollector() {
    #
    # execute and require setup artifacts
    #
    if [ ! -e "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/URI" ]
    then
        echo "Extraction artifact file of agility ${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/URI not found. Exiting."
        exit 1
    fi

    touch $AGILITY_HOME/AGILITY_COLLECTOR_SETUP
    URI=$(cat "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/URI")
    grep $URI $AGILITY_HOME/AGILITY_COLLECTOR_SETUP
    if [ "$?" -ne "0" ]
    then
        if [ -e "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/setup.sh" ]
        then
            mv  "${SETUP_SCRIPT_DIR_AGILITY_COLLECTOR}/setup.sh" $AGILITY_HOME
            /bin/bash ./setup.sh
            if [ "$?" -ne "0" ]
            then
                exit -1
            fi
            rm -f ./setup.sh
        fi
        echo $URI >> $AGILITY_HOME/AGILITY_COLLECTOR_SETUP
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
            cp $f ${AGILITY_HOME}/etc/$filename
         fi
      else
         ls ${AGILITY_HOME}/etc/$filename > /dev/null 2>&1
         if [[ $? -eq 0 ]]
         then
            echo "A file named $filename already exists in $AGILITY_HOME/etc/. It will be backed up in $AGILITY_HOME/etc-backup and replaced with $f."
            cp ${AGILITY_HOME}/etc/$filename ${AGILITY_HOME}/etc-backup/$filename
            cp $f ${AGILITY_HOME}/etc/$filename
         else
            echo "Copying $filename to $AGILITY_HOME/etc/."
            cp $f ${AGILITY_HOME}/etc/$filename
         fi
      fi
   done
}

function writeDatabaseCfg() {
    DB_CFG_FNAME="$AGILITY_HOME/etc/com.servicemesh.agility.database.cfg"

    echo "# Generated file -- DO NOT EDIT." > "$DB_CFG_FNAME"
    echo  >> "$DB_CFG_FNAME"
    echo "# the DB URL does not include the database name - it will be added dynamically"  >> "$DB_CFG_FNAME"
    echo "dbDriver=com.mysql.jdbc.Driver"  >> "$DB_CFG_FNAME"
    echo "dbUrl=jdbc:mysql://$MYSQL_PORT_3306_TCP_ADDR:$MYSQL_PORT_3306_TCP_PORT/" >> "$DB_CFG_FNAME"
    echo "dbUser=$MYSQL_USER" >> "$DB_CFG_FNAME"
    echo "dbPasswd=$MYSQL_PASSWORD" >> "$DB_CFG_FNAME"
    echo "dbProps=useSSL=false" >> "$DB_CFG_FNAME"
    echo  >> "$DB_CFG_FNAME"
    echo "# the packet value must be consistent between master, slave, and mysqldump" >> "$DB_CFG_FNAME"
    echo "max_allowed_packet=16M" >> "$DB_CFG_FNAME"
}

function writeThreadPoolCfg() {
    THREADPOOL_CFG_FNAME="$AGILITY_HOME/etc/com.servicemesh.agility.threadpool.cfg"
    echo "# Generated file -- DO NOT EDIT." > "$THREADPOOL_CFG_FNAME"
    echo  >> "$THREADPOOL_CFG_FNAME"

    if [ -z "${!THREADPOOL_SIZE}" ]
    then
        echo "threadpool.primary.poolSize=48"  >> "$THREADPOOL_CFG_FNAME"
    else
        echo "threadpool.primary.poolSize=$THREADPOOL_SIZE"  >> "$THREADPOOL_CFG_FNAME"
    fi

    if [ -z "${!THREADPOOL_QUEUE_CAPACITY}" ]
    then
        echo "threadpool.primary.queueCapacity=8192" >> "$THREADPOOL_CFG_FNAME"
    else
        echo "threadpool.primary.queueCapacity=$THREADPOOL_QUEUE_CAPACITY" >> "$THREADPOOL_CFG_FNAME"
    fi
}

showTitle "Validating environment variables"
checkCollectorEnv

showTitle "Loading etc/ files"
loadEtcFiles

showTitle "Configuring boot features"
setupCollectorFeatures

showTitle "Waiting for MySQL container to start"

/bin/bash $AGILITY_HOME/wait_for_service.sh -t 3000 ${MYSQL_PORT_3306_TCP_ADDR}:${MYSQL_PORT_3306_TCP_PORT}

if [ $? -ne 0 ]
then
    echo "Unable to communicate with mysql cluster in the time allowed.  Exiting..."
    exit 1
fi

showTitle "Configure database settings"
writeDatabaseCfg

showTitle "Configure the threadpool settings"
writeThreadPoolCfg

showTitle "Download and extract the Agility Collector setup"
extractAgilityCollector

showTitle "Setup the Agility Collector"
setupAgilityCollector

showTitle "Starting the Agility Collector"
exec $*
