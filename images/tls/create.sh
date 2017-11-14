#!/bin/bash

if [ ! -e ca.crt ]
then

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

  # create server key
  openssl genrsa -out server.pem 4096
  openssl req -subj "/CN=$DOCKER_MACHINE_NAME" -sha256 -new -key server.pem -out server.csr

  echo subjectAltName = IP:$(docker-machine ip $DOCKER_MACHINE_NAME),IP:127.0.0.1 > extfile.cnf
  openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.crt -CAkey ca.pem -CAcreateserial -out server.crt -extfile extfile.cnf
  rm extfile.cnf

  # create client key
  openssl genrsa -out client.pem 4096
  openssl req -subj "/CN=$DOCKER_MACHINE_NAME" -new -key client.pem -out client.csr

  echo extendedKeyUsage = clientAuth > extfile.cnf
  openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.crt -CAkey ca.pem -CAcreateserial -out client.crt -extfile extfile.cnf
  rm extfile.cnf

fi
