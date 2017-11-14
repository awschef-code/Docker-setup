#!/bin/bash

cp conf/zoo.cfg.template conf/zoo.cfg

NODES=$(getent hosts tasks.${ZOOKEEPER_SERVICE:-zookeeper} | awk '{ print $1 }' | sort)
echo $NODES

arr=($NODES)
cnt=${#arr[@]}
if [ $cnt -gt 1 ]
then
    let n=1;
    for node in $NODES
    do
        echo "server.$n=$node:2888:3888" >> conf/zoo.cfg
        ip addr | grep "$node" >/dev/null
        if [ $? -eq 0 ];
        then
            echo $n > /var/lib/zookeeper/myid
            echo MYID=$n
        fi
        let n=n+1
    done
fi

exec "$@"
