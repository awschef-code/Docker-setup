#!/bin/bash

source /usr/lib/cgi-bin/common/utilFunctions.sh

LOGMESSAGEPREFIX="Log Rotation"
LOGFILEPATH="/var/log/adapters-backup"
LOGFILEBASENAME="downloadbackup"
LOGEXT="log"
logFileName="${LOGFILEPATH}/${LOGFILEBASENAME}.${LOGEXT}"
todaysDate=`date +%F`

rotateTodaysLogFile() {
  todaysLogFileName="${LOGFILEPATH}/${LOGFILEBASENAME}-${todaysDate}.${LOGEXT}"
  if [ ! -f "$todaysLogFileName" ]
  then
    if [ -f "${logFileName}" ]
    then
      mv $logFileName $todaysLogFileName
    else
      printErrorMessage "${LOGMESSAGEPREFIX}: Something fishy, can't find log file with name ${logFileName} to rotate." >> $logFileName
    fi
  else
    printLogMessage  "${LOGMESSAGEPREFIX}: A File with today's date already exists. Looks like file rotation was already done." >> $logFileName
    ls -l $todaysLogFileName >> $logFileName
  fi
}

deleteOldLogFiles() {
  filesToDelete=`find $LOGFILEPATH -type f -name "*.log" -mtime +6 -exec ls -l {} \;|wc -l`
  if [ $filesToDelete -ge 1 ]
  then
    printLogMessage "${LOGMESSAGEPREFIX}: Following old log files will be deleted." >> $logFileName
    find $LOGFILEPATH -type f -name "*.log" -mtime +6 -exec ls -l {} \; >>  $logFileName
    find $LOGFILEPATH -type f -name "*.log" -mtime +6 -exec rm {} \;
  else
    printLogMessage  "${LOGMESSAGEPREFIX}: No old log files to delete." >> $logFileName
  fi
}

printLogMessage "${LOGMESSAGEPREFIX}: Started Log file rotation" >> $logFileName
rotateTodaysLogFile
deleteOldLogFiles
