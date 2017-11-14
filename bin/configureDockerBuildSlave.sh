#!/bin/bash
#works with Ubuntu 16.04 LTS
sudo addgroup docker
sudo gpasswd -a ${USER} docker
sudo apt-get update -y
sudo apt-get install -y python-software-properties debconf-utils
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update -y
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get install -y oracle-java8-installer
sudo apt-get install -y ant
#copy "agilified" security jars to java lib
sudo cp ../images/java8/US_export_policy.jar /usr/lib/jvm/java-8-oracle/jre/lib/security
sudo cp ../images/java8/local_policy.jar /usr/lib/jvm/java-8-oracle/jre/lib/security

#ivy
sudo mkdir ivy
cd ivy
sudo wget ftp://mirror.reverse.net/pub/apache/ant/ivy/2.4.0/apache-ivy-2.4.0-bin.tar.gz
sudo tar xzvf apache-ivy-2.4.0-bin.tar.gz
sudo cp apache-ivy-2.4.0/ivy-2.4.0.jar /usr/share/ant/lib/
sudo chown root:root /usr/share/ant/lib/ivy-2.4.0.jar

sudo apt-get install -y jq

#we dont really need postfix, but it gets installed on upgrade/update
#so enable silent install with these placeholder settings
debconf-set-selections <<< "postfix postfix/mailname string your.hostname.com"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

sudo apt-get update -y && sudo apt-get upgrade -y

sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo apt-get update -y
sudo apt-get install -y apt-transport-https
sudo apt-get install -y linux-image-extra-virtual
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update -y
sudo apt-get install -y docker-engine
sudo docker info
KEYDIR="/dockerkeys"
sudo mkdir -p $KEYDIR
sudo chmod 777 $KEYDIR
cd $KEYDIR

if which expect >/dev/null; then
    echo expect exists, no need to install it...
else
    echo expect does not exist, install it...
    sudo apt-get -y install expect
fi
HOST=`hostname`
PWD=`pwd`
echo "configuring docker service..."
rm -f ca-key.pem
rm -f ca.pem
rm -f server-key.pem
rm -f server.csr
rm -f extfile*.cnf
rm -f server-cert.pem
rm -f client.csr
rm -f key.pem
rm -f cert.pem
echo subjectAltName = IP:127.0.0.1 > extfile.cnf
echo extendedKeyUsage = clientAuth > extfile2.cnf

expect <<- DONE
  set timeout -1
  spawn openssl genrsa -aes256 -out ca-key.pem 4096
  expect "Enter pass phrase for ca-key.pem:"
  send "changeme\n"
  expect "Verifying - Enter pass phrase for ca-key.pem:"
  send "changeme\n"
  expect eof
  spawn openssl req -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem
  expect "Enter pass phrase for ca-key.pem:"
  send "changeme\n"
  expect "AU\\\]:"
  send "US\n"
  expect "Some-State\\\]:"
  send "California\n"
  expect "\\\]:"
  send "Orinda\n"
  expect "Ltd\\\]:"
  send "CSC Cloud Group\n"
  expect "\\\]:"
  send "Product Development\n"
  expect "\\\]:"
  send "dockerbuildslave\n"
  expect "\\\]:"
  send "eberhard.hummel@servicemesh.com\n"
  expect eof
  spawn openssl genrsa -out server-key.pem 4096
  expect eof
  spawn openssl req -subj "/CN=$HOST" -sha256 -new -key server-key.pem -out server.csr
  expect eof
  spawn openssl x509 -req -days 3650 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf
  expect "Enter pass phrase for ca-key.pem:"
  send "changeme\n"
  expect eof
  spawn openssl genrsa -out key.pem 4096
  expect eof
  spawn openssl req -subj /CN=client -new -key key.pem -out client.csr
  expect eof
  spawn openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile2.cnf
  expect "Enter pass phrase for ca-key.pem:"
  send "changeme\n"
  expect eof
DONE
sudo rm -v client.csr server.csr
sudo chmod -v 0400 ca-key.pem key.pem server-key.pem
sudo chmod -v 0444 ca.pem server-cert.pem cert.pem
mkdir -pv ~/.docker
cp -v {ca,cert,key}.pem ~/.docker

#remove this line when the new dockerhub.servicemesh.com v2 is up"
echo "192.168.101.125 dockerhub.servicemesh.com dockerhub" | sudo tee -a /etc/hosts

sudo sed -i 's^ExecStart=/usr/bin/dockerd -H fd://^ExecStart=/usr/bin/dockerd^' /lib/systemd/system/docker.service
sudo systemctl daemon-reload

cat <<EOF > ~/daemon.json
{  "insecure-registries" : ["dockerhub.servicemesh.com"],
   "debug": true,
   "tls": true,
   "tlscacert": "/dockerkeys/ca.pem",
   "tlscert": "/dockerkeys/server-cert.pem",
   "tlskey": "/dockerkeys/server-key.pem",
   "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2376"]
}
EOF
sudo mv ~/daemon.json /etc/docker
sudo chown root:root /etc/docker/daemon.json

sudo service docker restart
sleep 20

echo "docker login as sudo smadmin"
sudo docker login -u="agility-autobuild" -p="GI6EEOPFWJIVSKDRHA6KPDYQSP85FF88OBKUUKECAVXBNHTTYDC4RVLVLM2YRKMR" dockerhub.servicemesh.com

sudo chown smadmin:smadmin /home/smadmin/.docker/config.json

#to avoid socket permission denied error, add the smadmin user to the docker group
sudo usermod -a -G docker smadmin
sudo chmod 666 /var/run/docker.sock
sleep 15

echo "docker login as smadmin"
docker login -u="agility-autobuild" -p="GI6EEOPFWJIVSKDRHA6KPDYQSP85FF88OBKUUKECAVXBNHTTYDC4RVLVLM2YRKMR" dockerhub.servicemesh.com


