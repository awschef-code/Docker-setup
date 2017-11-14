#!/bin/bash
export PATH=$PATH:/usr/local/mysqlsh/bin

function cluster()
{
    NODES=$(getent hosts tasks.${MYSQL_SERVICE:-mysql-gr} | awk '{ print $1 }' | sort)
    for node in $NODES
    do
        # wait until node is up
        echo "Waiting for $node"
        while ! nc -q 1 $node 3306 </dev/null >/dev/null
        do
          sleep 10
          getent hosts tasks.${MYSQL_SERVICE:-mysql-gr} | grep $node
          if [ $? -eq 1 ]
          then
             echo "$node no longer shows in the list of mysql-gr ips. Will try again with a refreshed list."
             return
          fi
        done
    done

    let n=0
    for node in $NODES
    do
        if [ $n -eq 0 ]; then
            nodes="\"$node\""
        else
            nodes="$nodes,\"$node\""
        fi
        n=$(expr $n + 1)
    done

    if [ ! -z "$NODES" ]
    then
        echo "nodes=$nodes"
        sed -e"s/NODES/$nodes/g" \
            -e"s/MYSQL_ROOT_USER/${MYSQL_ROOT_USER:-root}/g" \
            -e"s/MYSQL_ROOT_PASSWORD/${MYSQL_ROOT_PASSWORD}/g" \
            -e"s/MYSQL_GROUP_USER/${MYSQL_GROUP_USER:-innodb_cluster_admin}/g" \
            -e"s/MYSQL_GROUP_PASSWORD/${MYSQL_GROUP_PASSWORD}/g" \
            cluster.js > cluster.tmp.js
        mysqlsh --file=cluster.tmp.js
    fi
}

while true
do
    cluster;
    sleep ${HEALTH_CHECK_INTERVAL:-60}
done
