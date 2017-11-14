#!/bin/bash

# Owner: Dev Tools and Automation
# Email: cpe_devtools_automation@csc.com
# Description: This script takes care of installing DTR 2.0

# Trigger the script as below:
# bash <script-name> <docker_ee_url> <docker_ucp_admin_user> \
# <docker_ucp_admin_pwd> <docker_ucp_host_addr>

# Docker Trusted Registry 2.0 have below pre-requisites:
# Docker EE
# Docker Universal Control Plane (UCP)
# So, ensure you've installed above pre-requisites using dtr2.0_pre-req_install.sh
# before running this script.

# Docker Trusted Registry Installation
# ------------------------------------

# By default, UCP listens on 443. If you plan to install DTR on same node/host, 
# DTR installation fails with conflicting port error; as DTR also runs on (80 and) 443.
# So, after UCP installation is complete, login to UCP, go to 
# Admin > Admin Settings > Cluster Configuration > Controller Port:
# Change it to 8443 if not already set up that way.

# Also, please make below change:
# Admin > Admin Settings > Scheduler > 
# Allow Administrators To Deploy Containers On UCP Managers Or Nodes Running DTR
# check the above box

# Finish above 2 steps before proceeding with DTR installation
# UCP link: https://<ip-addr>:8443

# check if the script is triggered correctly
if [ $# -ne 3 ]; then

  echo "Incorrect number ($#) of arguments passed...
    Execute script as below:
    bash <script-name> <docker_ucp_url> <docker_ucp_admin_user>
    <docker_ucp_admin_pwd>

    script-name: $0
    docker_ucp_url: $1
    docker_ucp_admin_user: $2
    docker_ucp_admin_pwd: $3
    "
    exit 1
fi

docker_ucp_url=$1
docker_ucp_admin_user=$2
docker_ucp_admin_pwd=$3
    
# Pull the latest version of DTR
# replace <ucp-node-name> with the hostname of the UCP node where you want to deploy DTR
sudo docker pull docker/dtr:2.3.3

# Install DTR
sudo docker run -it --rm \
  docker/dtr:2.3.3 install \
  --ucp-insecure-tls \
  --ucp-url "$docker_ucp_url" \
  --ucp-username "$docker_ucp_admin_user" \
  --ucp-password "$docker_ucp_admin_pwd" \
  --dtr-storage-volume "/dtr-storage"
