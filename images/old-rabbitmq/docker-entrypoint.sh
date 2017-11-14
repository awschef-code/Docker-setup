#!/bin/bash
rabbitmq_agility_cluster_name="agility_rabbitmq"

########################################################################################################################
##### Functions here ##########
########################################################################################################################
function echoWithTime() {
    echo "`date '+%m/%d/%y %H:%M:%S'` :: $1"
}

function format_address()
{
    __format_address_result__="$(printf "%03d%03d%03d%03d" $(echo $1 | tr '.' ' '))"
}

startRabbitMQInDetachedMode(){
  rabbitmq-server -detached
  setClusterNameAndVerify
}

setClusterNameAndVerify() {
    #Cluster name we set earlier will be reset after rabbitMq is restarted at the end of this script.
    #That's why we are runnig this delayed script to set cluster name after rabbitmq is restarted.
    while :
    do
      sleep 5
      #echo "Trying to set cluster Name to $rabbitmq_agility_cluster_name"
      rabbitmqctl set_cluster_name "$rabbitmq_agility_cluster_name"
      currentClusterNameResult=$(rabbitmqctl cluster_status | grep "cluster_name" | grep "$rabbitmq_agility_cluster_name")
      if [[ $currentClusterNameResult == *"$rabbitmq_agility_cluster_name"* ]]
      then
        echoWithTime "Cluster name was set to $rabbitmq_agility_cluster_name"
        break
      else
        echoWithTime "Couldn't set cluster name. will retry in few seconds."
      fi
    done
}

waitForSwarmToSecureEnoughIPs() {
  if [ -z "$RABBITMQ_REPLICAS" ]
  then
    rabbitmqReplicaCount=0
  else
    rabbitmqReplicaCount=$RABBITMQ_REPLICAS
  fi

  if [ $rabbitmqReplicaCount -gt 0 ]
  then
    echoWithTime "going to check and wait for getent to have atleast $rabbitmqReplicaCount ips."
    while [ `getent hosts tasks.${RABBITMQ_SERVICE:-rabbitmq} | wc -l` -lt $rabbitmqReplicaCount ]
    do
      echoWithTime "Waiting for no.of ${RABBITMQ_SERVICE:-rabbitmq} tasks to be atleast $rabbitmqReplicaCount"
      sleep 3
    done
  fi
}

checkForRabbitNodeHealth() {
  rabbitNode=$1
  needToWait=$2
  healthCheckPassed=0

  while :
  do
    echoWithTime "Checking health of node: $rabbitNode"
    healthCheckResponse=`rabbitmqctl node_health_check -n $rabbitNode`
    #Checking node health and also cluster status to make sure node is completely started.
    clusterStatusResponse=`rabbitmqctl -n $rabbitNode cluster_status`
    echo "============== Health check response... ====================="
    echoWithTime "$healthCheckResponse"
    echo "============== Cluster status check response... ============="
    echoWithTime "$clusterStatusResponse"
    echo "============================================================="
    if [[ $healthCheckResponse == *"Health check passed"* ]]  && [[ $clusterStatusResponse == *"$rabbitmq_agility_cluster_name"* ]]
    then
        healthCheckPassed=0
        echoWithTime "$rabbitNode passed Health check, and cluster status has correct cluster name."
    else
        healthCheckPassed=1
        echoWithTime "$rabbitNode failed Health check or cluster is not yet setup"
    fi
    if [[ ( $healthCheckPassed -eq 0 ) || ( $needToWait == "false") ]]
    then
      #Either healthcheck passed or No need to wait for halth check to be passed.
      break
    else
      echoWithTime "Waiting for Health check to be passed for '$rabbitNode'"
      sleep 5
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
      RABBITMQ_NODENAME="rabbit@${HOSTNAME}"
  fi

  echo "NODENAME=$RABBIT_NODENAME"
  echo "NODENAME=$RABBIT_NODENAME" > /etc/rabbitmq/rabbitmq-env.conf; chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq-env.conf;
}

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

setupClusterWithJustOneNode() {
    node=$NODES
    format_address "$node"
    self_id=${__format_address_result__}
    echo -e "$node  r$self_id" >> /etc/hosts
    RABBITMQ_NODENAME="rabbit@r$self_id"
    echoWithTime "Cluster name will be set shortly after rabbitmq is started"
    setClusterNameAndVerify &
}

setupNetworkForMultipleNodes() {
  echoWithTime "in setupNetworkForMultipleNodes()......."
  NODES_ARRAY=(`echo $NODES | tr "\n" " "`)
  seed_addr=${NODES_ARRAY[0]}
  format_address "$seed_addr"
  seed_id=${__format_address_result__}
  for ((nodeIdx=0; nodeIdx<${#NODES_ARRAY[*]}; nodeIdx++))
  do
      node=${NODES_ARRAY[$nodeIdx]}
      format_address "$node"
      id=${__format_address_result__}
      echoWithTime "Index: $nodeIdx, node: $node"
      ip addr | grep "$node" >/dev/null
      if [ $? -eq 0 ]
      then
          self_addr=$node
          self_id=$id
          echoWithTime "Initialized self ID at self_id=$self_id"
      fi
      echo -e "$node  r$id" >> /etc/hosts
  done
  RABBITMQ_NODENAME="rabbit@r$self_id"
}

startClusterForNonInitialNodeInList() {
 echoWithTime "seed_id=$seed_id"
 echoWithTime "self_id=$self_id"

 # wait until seed is up
 while ! nc -q 1 $seed_addr 5672 </dev/null; do sleep 10; done

 startRabbitMQInDetachedMode
 rabbitmqctl stop_app
 echoWithTime "About to check for node health in wait mode..."
 checkForRabbitNodeHealth "rabbit@r$seed_id" "true"
 echoWithTime "Fetching new cluster info from master node with rabbitmqctl update_cluster_nodes rabbit@r$seed_id"
 rabbitmqctl update_cluster_nodes rabbit@r$seed_id
 rabbitmqctl join_cluster rabbit@r$seed_id
 rabbitmqctl start_app
 rabbitmqctl cluster_status
 rabbitmqctl stop
 sleep 10
 rabbitmqctl status
}

checkIfClusterExistsWithOtherNodes() {
  for node in $NODES
  do
    format_address "$node"
    currentNodeId=${__format_address_result__}
    ip addr | grep "$node" >/dev/null
    if [ $? -ne 0 ]
    then
        echoWithTime "Found some other node at id $currentNodeId, let's check it's health status."
        checkForRabbitNodeHealth "rabbit@r$currentNodeId" "false"
        if [ $? -eq 0 ]
        then
          someOtherNodeId=$currentNodeId
          break
        fi
    fi
  done
}

joinInitialNodeWithExistingCluster() {
  echoWithTime "RabbitMQ cluster exists and  rabbit@r$someOtherNodeId is already a part of that cluster.let's join that cluster."
  echoWithTime "Fetching new cluster info from master node with rabbitmqctl update_cluster_nodes rabbit@r$someOtherNodeId"
  rabbitmqctl update_cluster_nodes rabbit@r$someOtherNodeId
  echoWithTime "Joining cluster......."
  rabbitmqctl join_cluster rabbit@r$someOtherNodeId
  if [ $? -eq 0 ]
  then
    echoWithTime "****** Succesfully joined cluster...******"
  else
    echoWithTime "****** Failed to join cluster...******"
  fi
  rabbitmqctl start_app
  rabbitmqctl cluster_status
  rabbitmqctl status
}

startClusterForInitialNodeInList() {
  startRabbitMQInDetachedMode
  rabbitmqctl stop_app
  checkIfClusterExistsWithOtherNodes

  if [[ ! -z "$someOtherNodeId" ]]
  then
    joinInitialNodeWithExistingCluster
  else
    echoWithTime "It looks like no cluster exists,as no other RabbitMQ node is reachable."
    echoWithTime "let's make this node as first node in cluster."
  fi
  rabbitmqctl stop
  sleep 10
}

########################################################################################################################
##### Main Flow  starts here ##########
########################################################################################################################
waitForSwarmToSecureEnoughIPs
NODES=$(nslookup tasks.${RABBITMQ_SERVICE:-rabbitmq} | grep Address | grep -v "#53" | sed -e "s/Address: //" | sort -n -t "." -k4)
echo NODES=$NODES

seed_addr='127.0.0.1'
self_addr='127.0.0.1'
seed_id=0
self_id=0

arr=($NODES)
cnt=${#arr[@]}
let n=0

if [ $cnt -eq 1 ]
then
    setupClusterWithJustOneNode
elif [ $cnt -gt 1 ]
then
  setupNetworkForMultipleNodes
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

echoWithTime "Setup done.Starting RabbitMQ..."
exec /docker-entrypoint.sh "$@"
