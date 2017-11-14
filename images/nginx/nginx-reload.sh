#!/bin/bash
#
# The purpose of this script is to reload the nginx configuration when the Agility Platform containers
# currently part of the cluster change.  A change is considered to be:
#
# 1. A new Agility Platform container joined the cluster
# 2. An Agility Platform container exited
#
# This script is executed as a cron job.  Run `sudo crontab -u root -l` to find out the cron job config.
# Since cron doesn't support seconds granularity, and we want to execute this script every 2 seconds,
# a while loop that executes 30 times with a sleep of 2 seconds has been put in place.  This will guarantee
# that cron will run this script every minute, and the script will execute every 2 seconds within that minute.

# Retrieve list of Agility Platform container IP Addresses using DNS
getNodesUsingDNS() {
	echo $(getent hosts tasks.agility-platform | awk '{ print $1 }' | sort -n -t "." -k4)
}

#Reload the Nginx configuration to pick up the updated Agility Platform containers
reloadNginxConfig() {
	printLogMessage "Current nginx configuration running with Agility Platform NODES [$NODES_IN_CONFIG]"
    printLogMessage "Reloading nginx configuration with updated Agility Platform NODES [$CURRENT_NODES]"
    /usr/local/nginx/sbin/nginx -s reload
    echo "$CURRENT_NODES" > $NODES_FILE
}

function printLogMessage() {
    echo "`date '+%m/%d/%y %H:%M:%S'` :: $1"
}

#===== MAIN =====

# This is the file where Agility Platform nodes currently part of the nginx configuration will be stored
NODES_FILE=/usr/local/nginx/AP_NODES

COUNTER=0
while [  $COUNTER -lt 30 ]; do
	if [ -e "$NODES_FILE" ]
	then
		# Retrieving the list of Agility Platform nodes currently in the nginx configuration
		NODES_IN_CONFIG=`cat $NODES_FILE`
		arr_nodes_in_config=($NODES_IN_CONFIG)
		cnt_nodes_in_config=${#arr_nodes_in_config[@]}

		# Retrieving the list of Agility Platform nodes currently part of DNS
		CURRENT_NODES=$(getNodesUsingDNS)
		arr_current_nodes=($CURRENT_NODES)
		cnt_current_nodes=${#arr_current_nodes[@]}
	
		if [ "$cnt_nodes_in_config" -ne "$cnt_current_nodes" ]
		then
			# Found a difference between the nodes in nginx config and the nodes retrieved from dns,
			# therefore reload nginx config
			reloadNginxConfig
    	elif [ "$cnt_nodes_in_config" -ne 0 ] && [ "$cnt_current_nodes" -ne 0 ]; then
    			# For every current node, check if that node exists in the nginx configuration
    			for currNode in $CURRENT_NODES
    			do
    				needsReload=1 # Boolean flag to determine if reload of config is needed when there is a difference
    				for configNode in $NODES_IN_CONFIG
    				do
    					if [ "$currNode" == "$configNode" ]
    					then
    						needsReload=0 # Found a match so make sure to not reload and keep checking
    				    fi
    				done

    				# If needsReload is equals to 1 then that means we found a mismatch and we will need to reload nginx config
    				if [ "$needsReload" -eq 1 ]
    				then
    					#
    					reloadNginxConfig
    					break # No need to continue checking for differences since we already reloaded
    				fi
    			done
    	fi
	else
		NODES=$(getNodesUsingDNS)
		echo "$NODES" > $NODES_FILE
		printLogMessage "File $NODES_FILE created"
	fi
	sleep 2
	let COUNTER=COUNTER+1 
done
