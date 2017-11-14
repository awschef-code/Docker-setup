#!/bin/bash

getentWaitInseconds=3
maxAttemptsToGetMultipleIPsInGetint=10
maxAttemptsToGetSelfIPInGetInt=20

waitForSwarmToFindSelfIPInGetent() {
    taskToLookFor=$1
    printLogMessage "Checking if getent includes self IP."
    attemptCount=1

    while :
    do
      NODES=$(getTasksWithGetent $taskToLookFor)
      for node in $NODES
      do
        ip addr | grep -w "$node" >/dev/null
        if [ $? -eq 0 ];
        then
          printLogMessage "Found self IP in getent list....[$NODES]"
          return
        fi
        if [ $attemptCount -ge $maxAttemptsToGetSelfIPInGetInt ]
        then
          printLogMessage "Waited for $(($attemptCount * $getentWaitInseconds)) seconds to get self IP in getent list. no luck, giving up and exiting with failure."
          exit 1
        fi
      done
      printLogMessage "Attempt $attemptCount of $maxAttemptsToGetSelfIPInGetInt: Waiting to see self IP in the getent list..... so far, I've got [$NODES]"
      sleep $getentWaitInseconds
      let attemptCount=$attemptCount+1
    done
}

waitForSwarmToSecureEnoughIPs() {
    taskToLookFor=$1
    attemptCount=1

    printLogMessage "going to check and wait for getent to have multiple ips."
    while [ `getTasksWithGetent $taskToLookFor | tr " " "\n"  | wc -l` -lt 2 ]
    do
      printLogMessage "Waiting to get multiple IPs for $taskToLookFor task, $attemptCount of $maxAttemptsToGetMultipleIPsInGetint. so far I've got [$NODES]"
      if [ $attemptCount -ge $maxAttemptsToGetMultipleIPsInGetint ]
      then
        printLogMessage "Waited $(($attemptCount * $getentWaitInseconds)) seconds to get multiple IPs from getent. with assumption that this is a single node setup, and continuing to next steps."
        break;
      else
        sleep $getentWaitInseconds
      fi
      let attemptCount=$attemptCount+1
    done
    if [ $attemptCount -lt $maxAttemptsToGetMultipleIPsInGetint ]
    then
      printLogMessage "Okay, got multiple IPs. Let's move on..."
    fi
}
