#!/bin/bash

source ./common/utilFunctions.sh
source ./common/getentWaitScript.sh

ZK_STOP_WAIT_MAX=20
function findWorkingZookeeperServer() {
  WORKINGZKNODE="localhost"
  for currentnode in $NODES
  do
    if [ "$currentnode" == "$MYIPADDRESS" ]
    then
      #skipping localhost IP.
      continue
    else
      printLogMessage "Let's check if Zookeeper on $currentnode is up and running."
      bin/zkCli.sh -server $currentnode:2181 get /zookeeper/config
      if [ $? -eq 0 ]
      then
        WORKINGZKNODE="$currentnode"
        break
      fi
    fi
  done
}

function stopZookeeper() {
  bin/zkServer.sh stop
  ZK_STOP_WAIT_COUNT=0
  while true; do
    if ps -ef | grep -v "grep"  | grep -q "java"
    then
      if [[ $ZK_STOP_WAIT_COUNT -ge $ZK_STOP_WAIT_MAX ]]; then
          printLogMessage "Failed stop Zookeeper, exiting container."
          exit 1
      fi
      sleep 1
      printLogMessage "Waiting for Zookeeper process to be stopped, attempt $ZK_STOP_WAIT_COUNT"
      let ZK_STOP_WAIT_COUNT++
    else
      echo "Stopped Zookeeper."
      break
    fi
  done
}

ZOOKEEPER_TASK_NAME="${ZOOKEEPER_SERVICE:-zookeeper}"
skipCheckFile="/tmp/skipRealHealthCheck"
if [ ! -f $skipCheckFile ]
then
  touch $skipCheckFile
fi

#let's wait until first health check is executed and container is declared healthy (getent doesn't show other IPs until containers are healthy).
sleep 20
cp conf/zoo.cfg.template conf/zoo.cfg

waitForSwarmToFindSelfIPInGetent $ZOOKEEPER_TASK_NAME
waitForSwarmToSecureEnoughIPs $ZOOKEEPER_TASK_NAME

NODES=$(getTasksWithGetent $ZOOKEEPER_TASK_NAME)
echo "NODES=$NODES"

arr=($NODES)
cnt=${#arr[@]}
if [ $cnt -gt 1 ]
then
    printLogMessage "Setting up configuration with NODES [$NODES]"
    for node in $NODES
    do
        format_address "$node"
        node_id=${__format_address_result__}
        echo "server.$node_id=$node:2888:3888:participant" >> conf/zoo.cfg.dynamic
        ip addr | grep -w "$node" >/dev/null
        if [ $? -eq 0 ];
        then
            echo $node_id > /var/lib/zookeeper/myid
            MYID=$node_id
            echo MYID=$node_id
            MYIPADDRESS=$node
        fi
    done
    ALLZKSERVERS=`cat conf/zoo.cfg.dynamic| tr "\n" ", " | sed 's/.$//'`
    echo "$(<conf/zoo.cfg.dynamic)"
    printLogMessage "Starting zookeeper in background to reconfig cluster with latest containers."
    bin/zkServer.sh start
    printLogMessage "Finding working zookeeper node."
    findWorkingZookeeperServer
    printLogMessage "Found working zookeeper node at $WORKINGZKNODE, replacing members with "
    echo "$ALLZKSERVERS"
    bin/zkCli.sh -server $WORKINGZKNODE:2181 reconfig -members "$ALLZKSERVERS"
    printLogMessage "updated members list with $ALLZKSERVERS"
    printLogMessage " ************ let's print config from $WORKINGZKNODE:2181 **********"
    bin/zkCli.sh -server $WORKINGZKNODE:2181 get /zookeeper/config
    printLogMessage "Stopping Zookeeper server."
    stopZookeeper
    printLogMessage "Stopped zookeeper after reconfig, will be started in foreground."
else
  printLogMessage "Found only one node in list. Setting up configuration with NODE [$NODES]"
  node=$NODES
  format_address "$node"
  node_id=${__format_address_result__}
  echo "server.$node_id=$node:2888:3888" >> conf/zoo.cfg.dynamic
  echo $node_id > /var/lib/zookeeper/myid
  MYID=$node_id
  echo MYID=$node_id
  printLogMessage "Initializing Zookeeper with following server list."
  echo "$(<conf/zoo.cfg.dynamic)"
  printLogMessage "Since this is a single node cluster, there is no need to reconfig cluster. Zookeeper will be started in foreground."
fi

printLogMessage "Completed setup. about to start zookeeper."
printLogMessage "Removing dummy health check file ($skipCheckFile) to let real health check to take place."
rm -f $skipCheckFile
printLogMessage "Executing $@"
exec "$@"
