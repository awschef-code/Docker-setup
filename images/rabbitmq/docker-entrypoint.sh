#!/bin/bash

source ./common/utilFunctions.sh
source ./common/getentWaitScript.sh
source ./rabbitFunctions.sh

skipCheckFile="/tmp/skipRealHealthCheck"
if [ ! -f $skipCheckFile ]
then
  touch $skipCheckFile
fi
#let's wait until first health check is executed and container is declared healthy (getent doesn't show other IPs until containers are healthy).
sleep 20

rabbitmq_agility_cluster_name="agility_rabbitmq"
RABBITMQ_TASK_NAME="${RABBITMQ_SERVICE:-rabbitmq}"
RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS=10
RABBIT_CLUSTER_CHECK_WAIT_SECONDS=10

########################################################################################################################
##### Functions here ##########
########################################################################################################################

startRabbitMQInDetachedMode(){
  printLogMessage "About to start rabbitmq in detached mode."
  rabbitmq-server -detached
  setClusterNameAndVerify
}

setClusterNameAndVerify() {
    #Cluster name we set earlier will be reset after rabbitMq is restarted at the end of this script.
    #That's why we are runnig this delayed script to set cluster name after rabbitmq is restarted.
    setClusterNameAttempts=1
    while :
    do
      sleep 5
      printLogMessage "About to set cluster Name to $rabbitmq_agility_cluster_name, attempt $setClusterNameAttempts."
      rabbitmqctl set_cluster_name "$rabbitmq_agility_cluster_name"
      currentClusterNameResult=$(rabbitmqctl cluster_status | grep "cluster_name" | grep "$rabbitmq_agility_cluster_name")
      if [[ $currentClusterNameResult == *"$rabbitmq_agility_cluster_name"* ]]
      then
        printLogMessage "Cluster name was set to $rabbitmq_agility_cluster_name"
        break
      else
        if [ $setClusterNameAttempts -ge $RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS ]
        then
          printErrorMessage "Couldn't set cluster name even after $joinClusterAttempts attempts. exiting with error."
          exit 1
        fi
        printLogMessage "Couldn't set cluster name. will retry in few seconds."
        let setClusterNameAttempts=$setClusterNameAttempts+1
      fi
    done
}

checkForRabbitNodeHealth() {
  rabbitNode=$1
  needToWait=$2
  healthCheckPassed=0

  healthCheckAttempts=1
  while :
  do
    printLogMessage "Checking health of node: $rabbitNode, attempt $healthCheckAttempts"
    healthCheckResponse=`rabbitmqctl node_health_check -n $rabbitNode`
    #Checking node health and also cluster status to make sure node is completely started.
    clusterStatusResponse=`rabbitmqctl -n $rabbitNode cluster_status`
    echo "============== Health check response... ====================="
    printLogMessage "$healthCheckResponse"
    echo "============== Cluster status check response... ============="
    printLogMessage "$clusterStatusResponse"
    echo "============================================================="
    if [[ $healthCheckResponse == *"Health check passed"* ]]  && [[ $clusterStatusResponse == *"$rabbitmq_agility_cluster_name"* ]]
    then
        healthCheckPassed=0
        printLogMessage "$rabbitNode passed Health check, and cluster status has correct cluster name."
    else
        healthCheckPassed=1
        printLogMessage "$rabbitNode failed Health check or cluster is not yet setup"
    fi
    if [[ ( $healthCheckPassed -eq 0 ) || ( $needToWait == "false") ]]
    then
      #Either healthcheck passed or No need to wait for halth check to be passed.
      break
    else
      if [ $healthCheckAttempts -ge $RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS ]
      then
        printErrorMessage "Health check didn't pass for '$rabbitNode' even after $joinClusterAttempts attempts. exiting with error."
        exit 1
      fi
      let healthCheckAttempts=$healthCheckAttempts+1
      printLogMessage "Health check failed."
      sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS
    fi
  done
  return "$healthCheckPassed"
}

setRabbitMQNodeName() {
  RABBIT_NODENAME=$1

  if [ -z "$RABBIT_NODENAME" ]
  then
      if [ -z "$HOSTNAME" ]
      then
         HOSTNAME=`hostname -s`
      fi;
      RABBITMQ_NODENAME="rabbit@r${HOSTNAME}"
  fi

  echo "NODENAME=$RABBIT_NODENAME"
  echo "NODENAME=$RABBIT_NODENAME" > /etc/rabbitmq/rabbitmq-env.conf; chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq-env.conf;
}

# Erlang cookie is required for RabbitMQ cluster. let's set it up.
setErlangCookieForCluster() {
  ERLANG_COOKIE=$1
  if [ ! -z "$ERLANG_COOKIE" ]
  then
     cookie=/var/lib/rabbitmq/.erlang.cookie
     echo "$ERLANG_COOKIE" > $cookie
     chown rabbitmq:rabbitmq $cookie
     chmod 0400 $cookie
  fi
}

# Found only one node in cluster. Let's set up cluster with just one node.
setupClusterWithJustOneNode() {
    node=$NODES
    format_address "$node"
    self_id=${__format_address_result__}
    echo -e "$node  r$self_id" >> /etc/hosts
    RABBITMQ_NODENAME="rabbit@r$self_id"
    printLogMessage "Cluster name will be set shortly after rabbitmq is started"
    setClusterNameAndVerify &
}

# Found other nodes for this cluster. let's setup network configuration with those nodes.
setupNetworkForMultipleNodes() {
  printLogMessage "in setupNetworkForMultipleNodes()......."
  NODES_ARRAY=(`echo $NODES | tr "\n" " "`)
  seed_addr=${NODES_ARRAY[0]}
  format_address "$seed_addr"
  seed_id=${__format_address_result__}
  for ((nodeIdx=0; nodeIdx<${#NODES_ARRAY[*]}; nodeIdx++))
  do
      node=${NODES_ARRAY[$nodeIdx]}
      format_address "$node"
      id=${__format_address_result__}
      printLogMessage "Index: $nodeIdx, node: $node"
      ip addr | grep -w "$node" >/dev/null
      if [ $? -eq 0 ]
      then
          self_addr=$node
          self_id=$id
          printLogMessage "Initialized self ID at self_id=$self_id"
      fi
      echo -e "$node  r$id" >> /etc/hosts
  done
  RABBITMQ_NODENAME="rabbit@r$self_id"
}

# A cluster already exists. Let's get the cluster info for this node from master node.
startClusterForNonInitialNodeInList() {
   printLogMessage "seed_id=$seed_id"
   printLogMessage "self_id=$self_id"

   # wait until seed is up for 2 minutes
   printLogMessage "About to check connectivity to $seed_addr:5672"
   RABBIT_CLUSTER_CHECK_RETRY_ATTEMPTS=12
   WAIT_TIME=$((($RABBIT_CLUSTER_CHECK_RETRY_ATTEMPTS * $RABBIT_CLUSTER_CHECK_WAIT_SECONDS) / 60))

   while [ $RABBIT_CLUSTER_CHECK_RETRY_ATTEMPTS -gt 0 ]; 
   do 
      if nc -q 1 $seed_addr 5672 </dev/null;
      then
        break;
      fi
      sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS; 
      let RABBIT_CLUSTER_CHECK_RETRY_ATTEMPTS=RABBIT_CLUSTER_CHECK_RETRY_ATTEMPTS-1 
   done

   if [ $RABBIT_CLUSTER_CHECK_RETRY_ATTEMPTS -eq 0 ]
   then
      printErrorMessage "Waited for $WAIT_TIME mintues to acquire connection to $seed_addr:5672. exiting with error."
      exit 1
   fi

   printLogMessage "completed connectivity check with $seed_addr:5672"

   startRabbitMQInDetachedMode
   #stop_app is required to update cluster information.
   rabbitmqctl stop_app
   printLogMessage "About to check for node health in wait mode..."
   checkForRabbitNodeHealth "rabbit@r$seed_id" "true"
   joinRabbitMQCluster "rabbit@r$seed_id"
}

# Check if RabbitMQ cluster with other nodes already exists.
checkIfClusterExistsWithOtherNodes() {
  for node in $NODES
  do
    format_address "$node"
    currentNodeId=${__format_address_result__}
    ip addr | grep -w "$node" >/dev/null
    if [ $? -ne 0 ]
    then
        printLogMessage "Found some other node at id $currentNodeId, let's check it's health status."
        checkForRabbitNodeHealth "rabbit@r$currentNodeId" "false"
        if [ $? -eq 0 ]
        then
          someOtherNodeId=$currentNodeId
          break
        fi
    fi
  done
}

function joinRabbitMQCluster() {
    local masterNodeId=$1

    printLogMessage "RabbitMQ cluster exists and $masterNodeId is already a part of that cluster.let's join that cluster."
    printLogMessage "Fetching new cluster info from master node with rabbitmqctl update_cluster_nodes $masterNodeId"
    rabbitmqctl update_cluster_nodes $masterNodeId
    joinClusterAttempts=1
    sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS
    while :
    do
      printLogMessage "Joining cluster with $masterNodeId, attempt $joinClusterAttempts"
      rabbitmqctl join_cluster $masterNodeId
      if [ $? -eq 0 ]
      then
        printLogMessage "successfiully joined cluster with $masterNodeId."
        break
      else
        if [ $joinClusterAttempts -ge $RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS ]
        then
          printErrorMessage "Couldn't join cluster with $masterNodeId even after $joinClusterAttempts attempts. exiting with error."
          exit 1
        fi
        let joinClusterAttempts=$joinClusterAttempts+1
        printLogMessage "Failed to join cluster with $masterNodeId. let's try it again after few seconds."
        sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS
      fi
    done

    rabbitmqctl start_app
    rabbitmqctl cluster_status
    stopRabbitMQ
    sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS
    rabbitmqctl status
}

# Start RabbitMQ with new/existing cluster.
startClusterForInitialNodeInList() {
  startRabbitMQInDetachedMode
  #stop_app is required to update cluster information.
  rabbitmqctl stop_app
  checkIfClusterExistsWithOtherNodes

  if [[ ! -z "$someOtherNodeId" ]]
  then
    # Join current node into an existing RabbitMQ cluster.
    joinRabbitMQCluster "rabbit@r$someOtherNodeId"
  else
    printLogMessage "It looks like no cluster exists,as no other RabbitMQ node is reachable."
    printLogMessage "let's make this node as first node in cluster."
    stopRabbitMQ
  fi
}

# Stop RabbitMQ. But, check if the cluster setup is done with all nodes in cluster. If not, exit with error.
function stopRabbitMQ() {
  local currentAttempt=1

  # need to do start_app to query cluster_status. app was stopped earlier to update cluster information.
  rabbitmqctl start_app
  printLogMessage "About to check cluster state, before stopping rabbitMQ."
  # Making sure cluster includes all expected nodes in this cluster.
  # Give it couple of tries to get it right. Exit with error, if it is still not including all expected nodes.
  printLogMessage "Actual nodes: `getRabbitClusterNodes`"
  printLogMessage "Expected nodes: `getNodesFromRabbitTasks`"

  while [ `areAllNodesInOneCluster` -ne 0 ] && [ $currentAttempt -lt $RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS ]
  do
    printLogMessage "Attempt $currentAttempt of $RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS : couldn't find all expected nodes in RabbitMQ cluster."
    let currentAttempt=$currentAttempt+1
    sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS
    printLogMessage "Actual nodes: `getRabbitClusterNodes`"
    printLogMessage "Expected nodes: `getNodesFromRabbitTasks`"

  done
  if [ $currentAttempt -ge $RABBIT_CLUSTER_CHECK_MAX_ATTEMPTS ]
  then
    printErrorMessage "Even after few attempts for $(($currentAttempt * $RABBIT_CLUSTER_CHECK_WAIT_SECONDS)) seconds, couldn't find all expected nodes in cluster. Exiting container with error."
    exit 1
  fi
  printLogMessage "Found all expeted nodes in RabbitMQ cluster. let's proceed with the Rabbit show..."
  sleep $RABBIT_CLUSTER_CHECK_WAIT_SECONDS
  rabbitmqctl stop
  sleep 10
}

#setup Cluster
function setupCluster() {
  if [ $cnt -eq 1 ]
  then
    setupClusterWithJustOneNode
  elif [ $cnt -gt 1 ]
  then
    setupNetworkForMultipleNodes
  fi
}

########################################################################################################################
##### Main Flow  starts here ##########
########################################################################################################################
waitForSwarmToFindSelfIPInGetent $RABBITMQ_TASK_NAME
waitForSwarmToSecureEnoughIPs $RABBITMQ_TASK_NAME
NODES=$(getTasksWithGetent $RABBITMQ_TASK_NAME)
echo NODES=$NODES

seed_addr='127.0.0.1'
self_addr='127.0.0.1'
seed_id=0
self_id=0

arr=($NODES)
cnt=${#arr[@]}
let n=0

setupCluster
# let's check if RabbitMQ containers list has changed. this can happen as getent is not cnosistent and it can take
#  somtime to report all containers. If list is different from earlier, then let's re-run Rabbitmq setup.
NEW_NODES_LIST=$(getTasksWithGetent $RABBITMQ_TASK_NAME)

if [[ "$NODES" == "$NEW_NODES_LIST" ]]
then
  printLogMessage "No change in RabbitMQ containers, let's continue...."
else
  printLogMessage "RabbitMQ containers list has changed. let's rerun RabbitMQ cluster setup with these new nodes "
  printLogMessage "$NEW_NODES_LIST"
  NODES=$NEW_NODES_LIST
  setupCluster
fi

setRabbitMQNodeName "$RABBITMQ_NODENAME"
setErlangCookieForCluster $RABBITMQ_ERLANG_COOKIE

if ( [ $seed_id -ne $self_id ] && [ $cnt -gt 1 ])
then
  startClusterForNonInitialNodeInList
elif [ $cnt -gt 1 ]
then
  startClusterForInitialNodeInList
fi

# enable management for the telegraf plugin
rabbitmq-plugins enable rabbitmq_management

printLogMessage "Setup done.Starting RabbitMQ..."
printLogMessage "Removing dummy health check file to let real health check to take place."
rm -f $skipCheckFile
printLogMessage "Executing $@ "

exec "$@"
