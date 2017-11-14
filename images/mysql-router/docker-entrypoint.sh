#!/bin/bash

export PATH=$PATH:/usr/local/mysql-router/bin

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqlrouter "$@"
fi

# skip setup if they want an option that stops mysqld
wantHelp=
for arg; do
	case "$arg" in
		-'?'|--help|--print-defaults|-V|--version)
			wantHelp=1
			break
			;;
	esac
done

_datadir() {
 	"$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }'
 }


# allow the container to be started initally as root and switch to mysql user
if [ "$1" = 'mysqlrouter' -a -z "$wantHelp" -a "$(id -u)" = '0' ]; then

    echo "Bootstrapping config..."
    let status=1
    while [ $status -ne 0 ]
    do
        while [ -z "$NODES" ]
        do
            echo "Waiting for ${MYSQL_SERVICE:-mysql-gr}"
            sleep 10
            NODES=$(getent hosts tasks.${MYSQL_SERVICE:-mysql-gr} | awk '{ print $1 }' | sort)
        done
        echo NODES=$NODES

        let n=0
        for node in $NODES
        do
            if [ $n -eq 0 ]; then
                nodes="\"$node\""
            else
                nodes="$nodes,\"$node\""
            fi

            # wait until node is up
            echo "Waiting for $node"
            while ! nc -q 1 $node 13306 </dev/null >/dev/null; do sleep 10; done
            n=$(expr $n + 1)
        done

        echo "nodes=$nodes"
        sed -e"s/NODES/$nodes/g" \
            -e"s/MYSQL_ROOT_USER/${MYSQL_ROOT_USER:-root}/g" \
            -e"s/MYSQL_ROOT_PASSWORD/${MYSQL_ROOT_PASSWORD}/g" \
            -e"s/MYSQL_GROUP_USER/${MYSQL_GROUP_USER:-innodb_cluster_admin}/g" \
            -e"s/MYSQL_GROUP_PASSWORD/${MYSQL_GROUP_PASSWORD}/g" \
            findseed.js > findseed.tmp.js

        # Try several times to get an online R/W node
        seed=""

	router_instance_name=`hostname`-agility-mysql-router

        let numRetries=0
        while [ $numRetries -lt 6 ]
        do
            echo "Looking for online R/W node"
            seed=`mysqlsh --file=findseed.tmp.js`
            if [ -n "$seed" ]
            then
                echo "Found online R/W node $seed"
                mysqlrouter --bootstrap $seed --name="$router_instance_name" --force --user=mysql <<EOF
$MYSQL_ROOT_PASSWORD
EOF
                status=$?
                break
            else
                sleep 10
            fi
            numRetries=$(expr $numRetries + 1)
        done

    done

    sed -i ./mysqlrouter.conf \
        -e"s/level.*/level=DEBUG/" \
        -e"s/ttl=300/ttl=30/" \
        -e"/\\[DEFAULT\\]/a\\
logging_folder="\
        -e"/\\[routing:.*/a\\
max_connections=500"\
        -e"/\\[routing:.*/a\\
max_connect_errors=250"
    cat ./mysqlrouter.conf
    chown -R mysql:mysql /usr/local/mysql-router

    echo "Launching $@"
	exec gosu mysql "$BASH_SOURCE" "$@"
fi

exec "$@"
