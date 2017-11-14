#!/bin/bash

source /common/utilFunctions.sh

BACKUP_DIR=/tmp/backup
BACKUP_FILE_NAME="${BACKUP_DIR}/adapters_backup.zip"
BACKUP_URL="${ADAPTER_BACKUP_SERVICE_URL:-http://adapters-backup/adapters-backup/}"

downloadBackup(){
  mkdir -p $BACKUP_DIR
  chown -R archiva:archiva $BACKUP_DIR

  httpStatusCode=`curl -s -w "%{http_code}"  "$BACKUP_URL" -o "${BACKUP_FILE_NAME}"`
  if [ "$httpStatusCode" -eq "200" ]
  then
    printLogMessage "`date`: Downloaded backup file from ${BACKUP_URL}, Size: `du -h $BACKUP_FILE_NAME | awk '{print $1}'`"
    return 0
  else
    return 1
  fi
}

chown -R archiva:archiva /var/archiva

printLogMessage "Waiting for Adapters backup service to start......"
/bin/bash /common/wait_for_service.sh -t 60 ${ADAPTERS_BACKUP_HOST}:${ADAPTERS_BACKUP_PORT}
printLogMessage "Let's check if any Backup is available at Adapters backup service...."
downloadBackup
if [ $? -eq 0 ]
then
  if [ -s $BACKUP_FILE_NAME ]
  then
    printLogMessage "`date`: restoring adapters form backup file."
    unzip -o $BACKUP_FILE_NAME -d /var/archiva/repositories/extensions/
    chown -R archiva:archiva /var/archiva/repositories/extensions/
  fi
fi
printLogMessage "Starting archiva....."

exec gosu archiva "$@"
