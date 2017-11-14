#!/bin/bash
source config.sh

unset DOCKER_HOST
unset DOCKER_TLS_VERIFY
unset DOCKER_CERT_PATH


if [ -z "$SSH_KEY" ]
then
   echo "Please configure SSH_KEY in config.sh"
   exit 1
fi

if [ -z "$NODES" ]
then
   echo "Please configure NODES in config.sh"
   exit 1
fi

if [ -z "$NUM_NODES" ]
then
   echo "Please configure NUM_NODES in config.sh"
   exit 1
fi


# create certificate authority (ca)
openssl genrsa -aes256 -passout pass:password -out ca-password.pem 4096 
openssl rsa -passin pass:password -in ca-password.pem -out ca.pem
openssl req -new -x509 -days 365 -key ca.pem -sha256 -out ca.crt << EOF
US
TX
Austin
CSC
Cloud
Agility
.
EOF


let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}

   # create server key
   openssl genrsa -out server-$i.pem 4096
   openssl req -subj "/CN=aglity-$i" -sha256 -new -key server-$i.pem -out server-$i.csr

   echo subjectAltName = IP:$node,IP:127.0.0.1 > extfile.cnf
   openssl x509 -req -days 365 -sha256 -in server-$i.csr -CA ca.crt -CAkey ca.pem -CAcreateserial -out server-$i.crt -extfile extfile.cnf

   # create client key
   openssl genrsa -out client-$i.pem 4096
   openssl req -subj '/CN=agility-$i' -new -key client-$i.pem -out client-$i.csr

   echo extendedKeyUsage = clientAuth > extfile.cnf
   openssl x509 -req -days 365 -sha256 -in client-$i.csr -CA ca.crt -CAkey ca.pem -CAcreateserial -out client-$i.crt -extfile extfile.cnf

   scp -i $SSH_KEY ca.crt server-$i.pem server-$i.crt client-$i.pem client-$i.crt $SSH_USER@$node:~
   ssh -i $SSH_KEY $SSH_USER@$node \
      "sudo mkdir -p /var/tls; \
       sudo chmod 0700 /var/tls; \
       sudo mv ca.crt /var/tls; \
       sudo mv server-$i.pem /var/tls/server.pem; \
       sudo mv server-$i.crt /var/tls/server.crt; \
       sudo mv client-$i.pem /var/tls/client.pem; \
       sudo mv client-$i.crt /var/tls/client.crt; \
       sudo chown -R root /var/tls; \
       sudo /bin/sh -c 'chmod 0400 /var/tls/*;' \
      "
   let i++
done


#
# install ntp and etcd on each node
#
echo "127.0.0.1 localhost localhost.local" > hosts
let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}

   ssh -i $SSH_KEY $SSH_USER@$node \
     "sudo apt-get update; \
      sudo apt-get install -y ntp curl; \
      sudo /etc/init.d/ntp stop; \
      sudo ntpdate -s time.nist.gov; \
      sudo /etc/init.d/ntp start; \
      curl --silent -L  https://github.com/coreos/etcd/releases/download/v2.2.2/etcd-v2.2.2-linux-amd64.tar.gz | tar xz; \
      cd etcd-v2.2.2-linux-amd64; \
      sudo initctl stop etcd 1>/dev/null 2>&1; \
      sudo cp etcd* /usr/local/bin; \
      sudo mkdir -p /var/etcd; \
      cd ..; rm -rf etcd-v2.2.2-linux-amd64;"

   if [ -z "$initial_cluster" ]
   then
      initial_cluster=etcd-$i=https://$node:2380
   else
      initial_cluster=$initial_cluster,etcd-$i=https://$node:2380
   fi
   echo "$node	agility-$i" >> hosts
   docker_add_host="$docker_add_host --add-host=agility-$i:$node"
   let i++
done

let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}

   # generate a config file for etcd
   cat <<- EOF > etcd.override 
	env ETCD_INITIAL_CLUSTER="$initial_cluster"
	env ETCD_INITIAL_CLUSTER_STATE="new"
	env ETCD_INITIAL_CLUSTER_TOKEN="agility-cluster"
	env ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$node:2380"
	env ETCD_DATA_DIR="/var/etcd"
	env ETCD_LISTEN_PEER_URLS="https://0.0.0.0:2380,https://0.0.0.0:7001"
	env ETCD_LISTEN_CLIENT_URLS="http://127.0.0.1:2379,http://127.0.0.1:4001,https://$node:2379,https://$node:4001"
	env ETCD_ADVERTISE_CLIENT_URLS="https://$node:2379"
	env ETCD_NAME="etcd-$i"
	env ETCD_CA_FILE="/var/tls/ca.crt"
	env ETCD_CERT_FILE="/var/tls/server.crt"
	env ETCD_KEY_FILE="/var/tls/server.pem"
	env ETCD_PEER_CERT_FILE="/var/tls/server.crt"
	env ETCD_PEER_KEY_FILE="/var/tls/server.pem"
	EOF

   scp -q -i $SSH_KEY hosts $SSH_USER@$node:~
   scp -q -i $SSH_KEY etcd.* $SSH_USER@$node:~
   ssh -i $SSH_KEY $SSH_USER@$node \
    "sudo mv etcd.* /etc/init; \
     sudo mv hosts /etc/hosts; \
     sudo initctl start etcd; \
    "
   let i++
done
rm -f etcd.override extfile.cnf *.csr hosts

#
# install docker on each of nodes
#

let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}

   ssh -i $SSH_KEY $SSH_USER@$node \
     "sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D; \
      sudo /bin/sh -c 'echo \"deb https://apt.dockerproject.org/repo ubuntu-trusty main\" > /etc/apt/sources.list.d/docker.list'; \
      sudo /bin/sh -c 'echo DOCKER_OPTS=\\\"--bip=172.17.1.1/24 -H unix:// -H tcp://0.0.0.0:2376 --tlsverify=true --tlscacert=/var/tls/ca.crt --tlscert=/var/tls/server.crt --tlskey=/var/tls/server.pem --cluster-store=etcd://$node:2379 --cluster-advertise=eth0:2376  --cluster-store-opt kv.cacertfile=/var/tls/ca.crt --cluster-store-opt kv.certfile=/var/tls/client.crt --cluster-store-opt kv.keyfile=/var/tls/client.pem\\\" > /etc/default/docker'; \
      sudo apt-get update; \
      sudo apt-get install -y -o Dpkg::Options::=--force-confold docker-engine; \
      sudo /bin/sh -c 'until docker ps 1>/dev/null; do sleep 1; echo waiting for docker; done;'; \
     "
   let i++
done


#
# launch registrator on each of the nodes
#

let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}
   DOCKER_OPTS="-H tcp://$node:2376 --tls=true --tlscacert=./ca.crt --tlscert=./client-$i.crt --tlskey=./client-$i.pem"

   docker $DOCKER_OPTS pull gliderlabs/registrator
   docker $DOCKER_OPTS run -d \
      $docker_add_host \
      --restart=always \
      --name registrator \
      --net=host \
      --volume=/var/run/docker.sock:/tmp/docker.sock \
      gliderlabs/registrator \
      -ip $node \
      etcd://127.0.0.1:2379/services &
   let i++
done
wait

#
# launch mysql on each of the nodes
#

let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}
   DOCKER_OPTS="-H tcp://$node:2376 --tls=true --tlscacert=./ca.crt --tlscert=./client-$i.crt --tlskey=./client-$i.pem"

   docker $DOCKER_OPTS pull agility/mysql:5.7
   docker $DOCKER_OPTS run -d \
      $docker_add_host \
      --restart=always \
      --name mysql-$i \
      --publish=3306:3306 \
      -e MYSQL_SERVER_ID=$i \
      --volume=/var/tls:/var/tls \
      agility/mysql:5.7 &
   let i++
done
wait

#
# launch fabric manager on last node
#

let MYSQL_NODES=$NUM_NODES-1
node=${NODES[$NUM_NODES-1]}
DOCKER_OPTS="-H tcp://$node:2376 --tlsverify=true --tlscacert=./ca.crt --tlscert=./client-$NUM_NODES.crt --tlskey=./client-$NUM_NODES.pem"

docker $DOCKER_OPTS pull agility/fabric
docker $DOCKER_OPTS run -d \
   $docker_add_host \
   --restart=always \
   --name fabric \
   --publish=32274:32274 \
   --publish=32275:32275 \
   -e DOCKER_IP=$(docker-machine ip agility-$NUM_NODES) \
   -e MYSQL_NODES=$MYSQL_NODES \
   --volume=/var/tls:/var/tls \
   --link=mysql-$NUM_NODES:mysql \
   agility/fabric

#
# create a unique erlang cookie for the rabbitmq cluster
#
RABBITMQ_ERLANG_COOKIE=$(uuidgen | sed -e "s/-//g")

#
# launch rabbitmq on each node
#

let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}
   DOCKER_OPTS="-H tcp://$node:2376 --tls=true --tlscacert=./ca.crt --tlscert=./client-$i.crt --tlskey=./client-$i.pem"

   docker $DOCKER_OPTS pull agility/rabbitmq
   docker $DOCKER_OPTS run -d \
      $docker_add_host \
      --restart=always \
      --name rabbitmq-$i \
      --publish=4369:4369 \
      --publish=5671:5671 \
      --publish=5672:5672 \
      --publish=25672:25672 \
      -e "HOSTNAME=agility-$i" \
      -e "RABBITMQ_JOIN_CLUSTER=agility-1" \
      -e "RABBITMQ_ERLANG_COOKIE=$RABBITMQ_ERLANG_COOKIE" \
      --volume=/var/tls:/var/tls \
      agility/rabbitmq &
   let i++
done
wait

#
# launch zookeeper (TODO: clustered)
#

node=${NODES[$NUM_NODES-1]}
DOCKER_OPTS="-H tcp://$node:2376 --tls=true --tlscacert=./ca.crt --tlscert=./client-$NUM_NODES.crt --tlskey=./client-$NUM_NODES.pem"

docker $DOCKER_OPTS pull agility/zookeeper
docker $DOCKER_OPTS run -d \
   $docker_add_host \
   --restart=always \
   --name zookeeper \
   --publish 2181:2181 \
   --volume=/var/tls:/var/tls \
   agility/zookeeper

exit 0;

#
# launch agility on each of the nodes
#
#
#     -e MYSQL_FABRIC=true <-- to enable mysql fabric
#
let i=1
while [ $i -le $NUM_NODES ]
do
   node=${NODES[$i-1]}
   DOCKER_OPTS="-H tcp://$node:2376 --tls=true --tlscacert=./ca.crt --tlscert=./client-$i.crt --tlskey=./client-$i.pem"

   docker $DOCKER_OPTS pull agility/platform
   docker $DOCKER_OPTS run -d \
      $docker_add_host \
      --restart=always \
      --name agility \
      -e DOCKER_IP=$node \
      --publish=8080:8080  \
      --publish=8443:8443 \
      --volume=/var/tls:/var/tls \
      agility/platform &
   let i++
done
wait

