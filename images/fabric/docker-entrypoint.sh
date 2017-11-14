#!/bin/bash

CURLOPTS="-s"
MYSQLOPTS=""

sed -i -e "s/localhost:3306/${MYSQL_PORT_3306_TCP_ADDR}:${MYSQL_PORT_3306_TCP_PORT}/" \
       -e "s/localhost:32274/0.0.0.0:32274/" \
       -e "s/localhost:32275/0.0.0.0:32275/" \
       -e "s/password *=.*$/password = ${MYSQL_ENV_MYSQL_FABRIC_PASSWORD}/" \
       -e "s/user = *$/user = fabric/" \
       /etc/mysql/fabric.cfg

if [ -d /var/tls ]
then
  sed -i -e "s/ssl_ca *=.*$/ssl_ca = \/var\/tls\/ca.crt/" \
         -e "s/ssl_cert *=.*$/ssl_cert = \/var\/tls\/server.crt/" \
         -e "s/ssl_key *=.*$/ssl_key = \/var\/tls\/server.pem/" \
         /etc/mysql/fabric.cfg
  CURLOPTS="$CURLOPTS --cacert /var/tls/ca.crt --cert /var/tls/client.crt --key /var/tls/client.pem"
  ETCD=https://$DOCKER_IP:2379
  MYSQLOPTS="$MYSQLOPTS --ssl-ca=/var/tls/ca.crt --ssl-cert=/var/tls/client.crt --ssl-key=/var/tls/client.pem"
  echo MYSQLOPTS="$MYSQLOPTS"
else
  ETCD=http://$DOCKER_IP:2379
fi

dbpresent=$(mysql $MYSQLOPTS -h${MYSQL_PORT_3306_TCP_ADDR} -P${MYSQL_PORT_3306_TCP_PORT} -u${MYSQL_ENV_MYSQL_FABRIC_USER} -p${MYSQL_ENV_MYSQL_FABRIC_PASSWORD} -e "show databases" 2>/dev/null)
while [ "$?" != "0" ]
do
	echo "waiting for database"
	sleep 10
	dbpresent=$(mysql $MYSQLOPTS -h${MYSQL_PORT_3306_TCP_ADDR} -P${MYSQL_PORT_3306_TCP_PORT} -u${MYSQL_ENV_MYSQL_FABRIC_USER} -p${MYSQL_ENV_MYSQL_FABRIC_PASSWORD} -e "show databases" 2>/dev/null)
done

echo $dbpresent | grep fabric
if [ "$?" != "0" ]
then
	# create the mysqlfabric database and startup the service 
        mysqlfabric manage setup
        mysqlfabric manage start --daemon

	if [ -z "$MYSQL_NODES" ]
	then
		MYSQL_NODES=1
	fi

	# wait for all mysql nodes to start
        cnt=$(curl $CURLOPTS $ETCD/v2/keys/services/mysql | jq -r '.node.nodes | length')
        while [ $cnt -lt $MYSQL_NODES ]
        do
                sleep 10
                echo "Waiting for mysql nodes"
                cnt=$(curl $CURLOPTS $ETCD/v2/keys/services/mysql | jq -r '.node.nodes | length')
        done

	# create a mysql fabric group for these nodes
        mysqlfabric group create agility

	# add configured nodes
        json=$(curl $CURLOPTS $ETCD/v2/keys/services/mysql)
        let cnt=0
        while [ $cnt -lt $MYSQL_NODES ]
        do
                key=$(echo $json | jq -r ".node.nodes[$cnt].key")
		value=$(echo $json | jq -r ".node.nodes[$cnt].value")
		echo $key = $value

                addr=$(echo $value | sed -e "s/:.*//")
        	port=$(echo $value | sed -e "s/[^:]*://")

		# wait for the database to initialize and start
		mysql $MYSQLOPTS -ufabric -p$MYSQL_ENV_MYSQL_FABRIC_PASSWORD -h$addr -P$port -e "select 1"
 		while [ "$?" != "0" ]
		do
			echo "waiting for mysql instance $value"
			sleep 10
			mysql $MYSQLOPTS -ufabric -p$MYSQL_ENV_MYSQL_FABRIC_PASSWORD -h$addr -P$port -e "select 1"
		done

		# default first node as the master
		echo $key | grep mysql-1
		if [ "$?" == "0" ]
		then
			master=$value
			echo Master=$value
		fi
                mysqlfabric group add agility $value
                let cnt=cnt+1
        done
	mysqlfabric group lookup_servers agility

	if [ "$master" != "" ]
	then
		uuid=$(mysqlfabric group lookup_servers agility | grep $master | cut -d " " -f 1)
	fi
	if [ "$uuid" != "" ]
	then
		echo Master=$uuid
		mysqlfabric group promote agility --slave_id=$uuid
	else
		mysqlfabric group promote agility
	fi
        mysqlfabric manage stop
fi

exec "$@"
