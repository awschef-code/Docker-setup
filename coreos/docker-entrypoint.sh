#!/bin/bash
ENDPOINT=--endpoint=unix:////coreos/var/run/fleet.sock 

fleetctl $ENDPOINT submit registrator\@.service
fleetctl $ENDPOINT submit mysql\@.service
fleetctl $ENDPOINT submit fabric\@.service
fleetctl $ENDPOINT submit agility\@.service
fleetctl $ENDPOINT submit nginx\@.service

if [ -z "$CLUSTER_NODES" ]
then
   CLUSTER_NODES=1
fi;

#
# start registrator on each of the nodes
#
let cnt=1;
while [ $cnt -le $CLUSTER_NODES ];
do
	fleetctl $ENDPOINT start registrator\@$cnt
	fleetctl $ENDPOINT start mysql\@$cnt
	let cnt++
done

fleetctl $ENDPOINT start fabric@$CLUSTER_NODES.service
fleetctl $ENDPOINT start rabbitmq.service
fleetctl $ENDPOINT start zookeeper.service

if [ -z "$AGILITY_INSTANCES" ]
then
   AGILITY_INSTANCES=1
fi;

let cnt=1;
while [ $cnt -le $AGILITY_INSTANCES ];
do
	fleetctl $ENDPOINT start agility\@$cnt
	let cnt++
done

let cnt=1;
while [ $cnt -le $CLUSTER_NODES ];
do
	fleetctl $ENDPOINT start nginx\@$cnt
	let cnt++
done
