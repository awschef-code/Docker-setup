#!/bin/bash
docker-machine stop dev
VBoxManage modifyvm "dev" --memory 8192
docker-machine start dev
