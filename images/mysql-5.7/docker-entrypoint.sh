#!/bin/bash
set -eo pipefail
shopt -s nullglob

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

# allow the container to be started with `--user`
if [ "$1" = 'mysqld' -a -z "$wantHelp" -a "$(id -u)" = '0' ]; then
	DATADIR="$(_datadir "$@")"
 	mkdir -p "$DATADIR"
 	chown -R mysql:mysql "$DATADIR"
	exec gosu mysql "$BASH_SOURCE" "$@"
fi
if [ "$1" = 'mysqld' -a -z "$wantHelp" ]; then
	# Get config
	DATADIR="$(_datadir "$@")"

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
			exit 1
		fi

		# update server id
		if [ "$MYSQL_SERVER_ID" != "" ];
		then
			sed -i -e "s/server_id.*$/server_id=$MYSQL_SERVER_ID/" /etc/mysql/conf.d/agility.cnf
		fi;

		mkdir -p "$DATADIR"

		echo 'Initializing database'
		mysqld --initialize-insecure=on --datadir="$DATADIR"
		echo "$@"
		echo 'Database initialized'

		# setup tls
		if [ -e /var/tls/ca.crt ];
		then
			cp /var/tls/ca.crt $DATADIR/ca.pem
			cp /var/tls/server.crt $DATADIR/server-cert.pem
			cp /var/tls/server.pem $DATADIR/server-key.pem
			chown mysql:mysql $DATADIR/*.pem
			chmod 0400 $DATADIR/*.pem
		fi;

		mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
		echo "$@"
		pid="$!"

		mysql=( mysql --protocol=socket -uroot )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
 			# sed is for https://bugs.mysql.com/bug.php?id=20545
 			mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
 		fi
		echo "${mysql[@]}"

		"${mysql[@]}" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			DELETE FROM mysql.user ;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES ;
		EOSQL

		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=( "$MYSQL_DATABASE" )
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | "${mysql[@]}"
			echo "GRANT ALL ON *.* TO '$MYSQL_USER'@'%' ;" | "${mysql[@]}"
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		if [ "$MYSQL_FABRIC_USER" -a "$MYSQL_FABRIC_PASSWORD" ]; then
			echo "CREATE USER '"$MYSQL_FABRIC_USER"'@'%' IDENTIFIED BY '"$MYSQL_FABRIC_PASSWORD"' ;" | "${mysql[@]}"
			echo "GRANT ALL ON *.* TO '"$MYSQL_FABRIC_USER"'@'%' ;" | "${mysql[@]}"
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		# clear all binlogs
		echo 'RESET MASTER ;' | "${mysql[@]}"

		echo
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

exec "$@"
