#!/bin/bash

# Query RabbitMQ to find what nodes are included in it's cluster.
function getRabbitClusterNodes() {
    echo `rabbitmqctl cluster_status | awk '/running_nodes,\[/,/\]/' | tr '\n' ' ' | sed -e 's/  *//g'| grep -Po '(?<=running_nodes,\[).+(?=\])' | sed 's/,/ /g'`
}

# get the nodes that are supposed to be in RabbitMQ cluster.
function getNodesFromRabbitTasks() {
  taskips=(`getent hosts tasks.rabbitmq | sed -e 's/  *tasks\.rabbitmq//g' | tr '\n' ' '`)
  tasknodes=()
  for currentip in ${taskips[@]}
  do
      format_address $currentip
      tasknodes+=("rabbit@r${__format_address_result__}")
  done
  echo ${tasknodes[@]}
}

# Check if all the nodes that are supposed to be in RabbitMQ cluster are actually in that cluster.
function areAllNodesInOneCluster(){
  local actualNodes=(`getRabbitClusterNodes`)
  local expectedNodes=(`getNodesFromRabbitTasks`)

  missingNodes=(`echo ${actualNodes[@]} ${expectedNodes[@]} | tr ' ' '\n' | sort | uniq -u`)
  if [ -z $missingNodes ]
  then
    echo 0
  else
    echo ${#missingNodes[@]}
  fi
}
