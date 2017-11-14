#!/bin/bash

# Owner: Dev Tools and Automation
# Email: cpe_devtools_automation@csc.com
# Description: This script takes care of installing pre-requisites
# (Docker EE and Docker UCP) required for DTR 2.0

# Trigger the script as below:
# bash <script-name> <docker_ee_url> <docker_ucp_admin_user> \
# <docker_ucp_admin_pwd> <docker_ucp_host_addr>

# check if the script is triggered correctly
if [ $# -ne 4 ]; then

  echo "Incorrect number ($#) of arguments passed...
    Execute script as below:
    bash <script-name> <docker_ee_url> <docker_ucp_admin_user>
    <docker_ucp_admin_pwd> <docker_ucp_host_addr>
    
    script-name: $0
    docker_ee_url: $1
    docker_ucp_admin_user: $2
    docker_ucp_admin_pwd: $3
    docker_ucp_host_addr: $4
    "
    exit 1
fi

# Step 1: Docker EE Installation
# ------------------------------

docker_ee_url=$1
docker_ucp_admin_user=$2
docker_ucp_admin_pwd=$3
docker_ucp_host_addr=$4
    
# un-install old versions
sudo apt-get remove docker docker-engine docker-ce docker.io -y

# update all packages
sudo apt-get update -y

# Install the linux-image-extra-* packages, which allow 
# Docker EE to use the aufs storage driver.
sudo apt-get install \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual -y

# Update the apt package index
sudo apt-get update -y

# Install packages to allow apt to use a repository over HTTPS
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common -y

# Add Docker’s official GPG key using your customer Docker EE repository URL
curl -fsSL $docker_ee_url/ubuntu/gpg | sudo apt-key add -

# Verify that you now have the key with the fingerprint
# DD91 1E99 5A64 A202 E859 07D6 BC14 F10B 6D08 5F96, 
# by searching for the last eight characters of the fingerprint.
sudo apt-key fingerprint 6D085F96

# Use the following command to set up the stable repository
sudo add-apt-repository \
   "deb [arch=amd64] $docker_ee_url/ubuntu \
   $(lsb_release -cs) \
   stable-17.06"

# Update the apt package index
sudo apt-get update -y

# Install the latest version of Docker EE
sudo apt-get install docker-ee -y

# Verify that Docker EE is installed correctly by running the hello-world image
sudo docker run hello-world

# Step 2: Docker UCP Installation
# --------------------------------

# Pull the latest version of UCP
sudo docker image pull docker/ucp:2.2.3

# Install UCP
# Take a note of UCP URL once installation is complete
sudo docker container run --rm -it --name ucp \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker/ucp:2.2.3 install \
  --admin-username "$docker_ucp_admin_user" \
  --admin-password "$docker_ucp_admin_pwd" \
  --host-address "$docker_ucp_host_addr" \
  --controller-port 8443
