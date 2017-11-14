#!/bin/bash

source /usr/lib/cgi-bin/common/utilFunctions.sh

BACKUP_DIR=/var/adapters-backup/data
BACKUP_FILE_NAME="${BACKUP_DIR}/adapters_backup.zip"
STAGING_FILE_NAME="${BACKUP_DIR}/adapters_backup_new.zip"
LOG_FILE_NAME="/var/log/adapters-backup/downloadbackup.log"
BACKUP_URL="${ARCHIVA_ADAPTERS_BACKUP_URL:-http://archiva:8080/adapters-backup/}"

function printFileSize() {
  echo `du -h $1 | awk '{print $1}'`
}

function removeFile () {
  if [ -f "$1" ]
  then
   rm "$1"
  fi
}

function downloadBackup() {
  caller=$1
  starttime=`date +%s`
  httpStatusCode=`curl -s -w "%{http_code}"  "$BACKUP_URL" -o "${STAGING_FILE_NAME}"`
  endtime=`date +%s`
  totaltime="$((endtime - starttime))"
  if [ "$httpStatusCode" -eq "200" ]
  then
    unzip -t $STAGING_FILE_NAME 2>&1 >&/dev/null
    if [ $? -eq 0 ]
    then
      mv "${STAGING_FILE_NAME}" "${BACKUP_FILE_NAME}"
      printLogMessage "$caller : Successfully downloaded backup file to $BACKUP_FILE_NAME, Time taken: ${totaltime}sec, Size: `printFileSize $BACKUP_FILE_NAME`" >> $LOG_FILE_NAME
    else
      printErrorMessage "$caller : $BACKUP_URL  Failed to download file. 'Archiva' service might have been stopped before downloading complete backup file. Response code: $httpStatusCode, Time taken: ${totaltime}sec, Size: `printFileSize $STAGING_FILE_NAME`" >> $LOG_FILE_NAME
    fi
  else
    printErrorMessage "$caller : $BACKUP_URL  Failed with Response code: $httpStatusCode, Time taken: ${totaltime}sec" >> $LOG_FILE_NAME
  fi
  removeFile "${STAGING_FILE_NAME}"
}
