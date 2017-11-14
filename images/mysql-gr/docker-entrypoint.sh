#!/bin/bash
set -o pipefail
shopt -s nullglob

CNF_FILE=/etc/mysql/my.cnf

#====================================================
# Parse out the expire-logs-days from config file, and
# print out the value.  Default to 7 if not found.
#====================================================
function getLogBinLifetime() {
	local lifetime=7
	if [ -e "$CNF_FILE" ]
	then
		local configed=`awk -F= '/expire-logs-days/ { print $2;  }' "$CNF_FILE" | tr -d " "`
		if [ -n "$configed" ]
		then
			lifetime=$configed
		fi
	fi
	echo $lifetime
}

#
#====================================================
# Prints 'true' if it appears to a viable database.
# It's viable if there any mysql files newer than
# the log bin expiration length (days).
#====================================================
function isViableDatabase() {
	local nLogDays=$(getLogBinLifetime)
	modernFields=$(find /var/lib/mysql -ctime -${nLogDays} -type f -print0 | xargs -0 -r stat --format '%Y :%y %n' | sort -nr | cut -d: -f2- | head -5)
	if [ -n "$modernFields" ]
	then
		echo "true"
	fi
}


function startLocalMysql() {
    localPid=""

    mysqld --user=mysql --datadir="$DATADIR" --group-replication=OFF --skip-networking &
    localPid="$!"

    mysql=( mysql --protocol=socket -u${MYSQL_USER} -p${MYSQL_PASSWORD} )

    for i in {30..0}
    do
        if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
            break
        fi
        echo >&2 'MySQL local (select) in progress...'
        sleep 1
    done

    if [ "$i" = 0 ]; then
        echo >&2 'MySQL start using existing volume data failed.'
        return 1
    fi

    return 0
}

function stopLocalMysql() {
    if [ -n "$localPid" ]
    then
        if kill -s TERM "$localPid"
        then
            wait "$localPid"
        fi
    fi
    localPid=""
}


function isRecoverable() {

    local routers=`getent hosts tasks.mysql-router | sed 's/ .*$//'`
    if [ -z "$routers" ]
    then
        echo >&2 "No mysql-routers available"
        echo "unknown"
        return
    fi

    # Wait up to 200 seconds for a valid mysql-router to be available
    local maxIters=10
    local waitInterval=20
    local iters=0

    while (( "$iters" < "$maxIters" )) && [ -z "$remoteGtids" ]
    do
        ((iters=iters+1))
        echo >&2 "Performing iteration $iters"

        routers=`getent hosts tasks.mysql-router | sed 's/ .*$//'`
        if [ -z "$routers" ]
        then
            echo >&2 "No mysql-routers available"
            echo "unknown"
            return
        fi

        for router in $routers
        do
            echo >&2 "Attempting query of mysql-router $router"

            local qresult=$(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h "$router" -P 6446 -s -r --connect-timeout=5 -e "select count(*) from information_schema.TABLES where table_name = 'TABLES';" 2>/dev/null)
            if [ $? -ne 0 ]
            then
                echo >&2 "Could not execute query on mysql-router $router"
                continue
            fi

            if [ ! "$qresult" = "1" ]
            then
                echo >&2 "Could not successfully execute query on mysql-router $router"
                continue
            fi

            local routerMysqlOut=$(mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h "$router" -P 6446 -s -r --connect-timeout=5 -e  "show global variables like 'gtid_executed';" 2>/dev/null)
            if [ $? -ne 0 ]
            then
                echo >&2 "Could not query GTIDs from mysql-router $router"
                continue
            fi

            remoteGtids=`echo "$routerMysqlOut" | sed 's/^gtid_executed *\(.*\)/\1/' | tr -d '\n\t '`
            if [ -z "$remoteGtids" ]
            then
                echo >&2 "No GTIDs found on R/W node for mysql-router $router"
                continue
            else
                echo >&2 "Found GTIDs on mysql-router $router"
                echo >&2 "Remote GTIDs: $remoteGtids"
                break
            fi
        done

        if [ -z "$remoteGtids" ]
        then
            echo >&2 "Sleeping $waitInterval seconds"
            sleep $waitInterval
        fi

    done

    if [ -z "$remoteGtids" ]
    then
        echo >&2 "No GTIDs found on R/W node on any mysql-router"
        echo "false"
        return
    fi

    local rc=""

    startLocalMysql

    if [ $? -ne 0 ]
    then
        rc="false"
    else
        local localMysqlOut=$(mysql --protocol=socket -u${MYSQL_USER} -p${MYSQL_PASSWORD} -s -r -e  "show global variables like 'gtid_executed';" 2>/dev/null)
        if [ $? -ne 0 ]
        then
            echo >&2 "Error querying for local GTIDs"
            rc="false"
        else
            local localGtids=`echo "$localMysqlOut" | sed 's/^gtid_executed *\(.*\)/\1/' | tr -d '\n\t '`
            if [ -z "$localGtids" ]
            then
                echo >&2 "No local GTIDs found"
                rc="true"
            else
                echo >&2 "Local GTIDs: $localGtids"
                local res=$(mysql --protocol=socket -u${MYSQL_USER} -p${MYSQL_PASSWORD} -s -r -e "SELECT GTID_SUBSET('$localGtids','$remoteGtids');" 2>/dev/null | tail -n 1)
                if [ $? -eq 0 -a "$res" = "1" ]
                then
                    echo >&2 "Local GTIDs are a valid subset of cluster GTIDs"
                    rc="true"
                else
                    rc="false"
                fi
            fi
        fi
    fi

    stopLocalMysql

    echo "$rc"
}

##############################################################
##################### MAIN ###################################
##############################################################

export PATH=$PATH:/usr/local/mysql-5.7.15-labs-gr090-linux-glibc2.5-x86_64/bin

echo "$BASH_SOURCE invoked by user $(id -u) with parameters: $@"

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
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

_errorlog() {
 	"$@" --verbose --help 2>/dev/null | awk '$1 == "log_error" { print $2; exit }'
 }

# allow the container to be started initally as root and switch to mysql user
if [ "$1" = 'mysqld' -a -z "$wantHelp" -a "$(id -u)" = '0' ]; then

    # adjust config while running as root
    if [ -e "$CNF_FILE" ]
    then
        ip_addr=$(ifconfig ${MYSQL_INTERFACE:-eth0} | grep "inet addr" | sed -e "s/.*addr://" -e "s/ .*$//")
        server_id=$(echo $ip_addr | sed -e "s/.*\.//")
        time_zone=`date +%:z`
        sed -i -e "s/server_id.*$/server_id=$server_id/" "$CNF_FILE"
        sed -i -e "s/group_replication_local_address.*$/group_replication_local_address=$ip_addr:13306/" "$CNF_FILE"
        sed -i -e "/\[mysqld\]/a report-host=${ip_addr}" "$CNF_FILE"
        sed -i -e "/\[mysqld\]/a default-time-zone=${time_zone}" "$CNF_FILE"
        sed -i -e "/\[mysqld\]/a log_timestamps=SYSTEM" "$CNF_FILE"
    fi

	DATADIR="$(_datadir "$@")"
	DATADIR=${DATADIR%/}
 	mkdir -p "$DATADIR"
 	chown -R mysql:mysql "$DATADIR"
	if [ -e "$DATADIR/error.log" ]
	then
		echo "Removing existing $DATADIR/error.log"
		rm -f "$DATADIR/error.log"
	fi
	rm -f /var/lib/mysql/mysql.sock.lock
	echo "Switching to run $BASH_SOURCE as user mysql"
	exec gosu mysql "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'mysqld' -a -z "$wantHelp" ]; then

	# Get config
	DATADIR="$(_datadir "$@")"
	DATADIR=${DATADIR%/}

	if [ -d "$DATADIR/mysql" ]; then
		canRecover=$(isRecoverable)
		if [ "${canRecover}" = "false" ]
		then
			echo "Database cannot be reused due to GTID mismatch."
			echo "Removing existing $DATADIR directory"
			rm -rf $DATADIR/*
		fi
	fi

	if [ -d "$DATADIR/mysql" ]; then
		isViable=$(isViableDatabase)
		if [ -z "$isViable" ]; then
			echo "Database appears too old to catch up fully via replication."
			echo "Removing existing $DATADIR directory"
			rm -rf $DATADIR/*
		else
			echo "Database will be used as is from existing $DATADIR"
		fi
	fi

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
			exit 1
		fi

		backupExists=`getent hosts tasks.${MYSQL_BACKUP_PORT_80_TCP_ADDR:-mysql-backup}`
		echo "mysql-backup host(s) found are: $backupExists"
		if [ -n "$backupExists" ]
		then
			nc -z ${MYSQL_BACKUP_PORT_80_TCP_ADDR:-mysql-backup} ${MYSQL_BACKUP_PORT_80_TCP_PORT:-80} </dev/null >/dev/null

			# Attempt to restore from  backup
			if [ "$?" -eq 0 ]
			then
				echo "Attempting to restore from mysql backup"
				BACKUPDIR=$(mktemp -d -t mysql-backup.XXXXXX)

				cd $DATADIR
				curl http://${MYSQL_BACKUP_PORT_80_TCP_ADDR:-mysql-backup}:${MYSQL_BACKUP_PORT_80_TCP_PORT:-80}/mysql-backup | \
					mysqlbackup --backup-dir=${TMPDIR:-/tmp}/$BACKUPDIR --datadir=$DATADIR --backup-image=- \
					--force --uncompress copy-back-and-apply-log

				if [ "${PIPESTATUS[0]}" !=  "0" -o "${PIPESTATUS[1]}" != "0" ]
				then
					echo "Restore from backup failed."
					rm -rf $DATADIR/*
					exit 1
				fi
			else
				echo "Database restore service was available but could not be reached. Aborting."
				exit 1
			fi
	   else
		   echo "Database restore service not available.  Initializing new database."
	   fi
	fi

	if [ ! -d "$DATADIR/mysql" ]; then
		mkdir -p "$DATADIR"

		echo 'Initializing database'
		mysqld --initialize-insecure=on --datadir="$DATADIR"
		echo 'Database initialized'

		mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL (select) init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		for i in {30..0}; do
			if echo "show variables LIKE 'super_read_only'" | "${mysql[@]}" | grep OFF; then
				break
			fi
			echo 'MySQL (super_read_only) init process in progress...'
			sleep 1
		done

		"${mysql[@]}" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			ALTER USER USER() IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES ;
		EOSQL

		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi
		echo "${mysql[@]}"

		if [ "$MYSQL_DATABASE" ]; then
			echo "Creating $MYSQL_DATABASE"
			"${mysql[@]}" <<-EOSQL
				SET @@SESSION.SQL_LOG_BIN=0;
				CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
EOSQL
			mysql+=( "$MYSQL_DATABASE" )
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "Creating $MYSQL_USER"
			"${mysql[@]}" <<-EOSQL
				SET @@SESSION.SQL_LOG_BIN=0;
				CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
				GRANT ALL ON *.* TO '$MYSQL_USER'@'%';
				FLUSH PRIVILEGES ;
EOSQL
		fi

		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${mysql[@]}" < "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${mysql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		echo
		echo 'MySQL init process done. Ready for start up.'
		echo
	fi

fi

touch /tmp/ready

exec "$@"
