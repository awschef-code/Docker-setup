FROM debian:jessie

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

# add gosu for easy step-down from root, and download mysql deb files while we have wget.
ENV GOSU_VERSION 1.7

RUN apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils && rm -rf /var/lib/apt/lists/*

RUN mkdir /docker-entrypoint-initdb.d

# gpg: key 5072E1F5: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5

ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.16-1debian8

RUN echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list

# FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
RUN set -x \
	&& apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates wget perl pwgen netcat \
   && apt-get install -f -y libaio1 libnuma1 systemd man-db libmecab2 psmisc init-system-helpers \
   && rm -rf /var/lib/apt/lists/* \
	&& echo "\nexport TERM=xterm" >> /etc/bash.bashrc \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& cd /tmp \
	&& wget http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/mysql-client/5.7.16+commercial-1debian8_amd64/mysql-client_5.7.16+commercial-1debian8_amd64.deb \
	&& wget http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/mysql-commercial-client/5.7.16+commercial-1debian8_amd64/mysql-commercial-client_5.7.16+commercial-1debian8_amd64.deb \
	&& wget http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/mysql-commercial-server/5.7.16+commercial-1debian8_amd64/mysql-commercial-server_5.7.16+commercial-1debian8_amd64.deb \
	&& wget http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/mysql-common/5.7.16+commercial-1debian8_amd64/mysql-common_5.7.16+commercial-1debian8_amd64.deb \
	&& wget http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/mysql-server/5.7.16+commercial-1debian8_amd64/mysql-server_5.7.16+commercial-1debian8_amd64.deb \
   && wget http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/meb/4.0.3-debian8-x86-64bit/meb-4.0.3-debian8-x86-64bit.deb \
	&& apt-get purge -y --auto-remove ca-certificates wget \
   && dpkg -i /tmp/mysql-common_5.7.16+commercial-1debian8_amd64.deb \
	&& dpkg -i /tmp/mysql-commercial-client_5.7.16+commercial-1debian8_amd64.deb \
	&& dpkg -i /tmp/mysql-client_5.7.16+commercial-1debian8_amd64.deb \
	&& dpkg -i /tmp/mysql-commercial-server_5.7.16+commercial-1debian8_amd64.deb \
	&& dpkg -i /tmp/mysql-server_5.7.16+commercial-1debian8_amd64.deb \
   && dpkg -i /tmp/meb-4.0.3-debian8-x86-64bit.deb \
	&& apt-get -f install \
	&& rm -rf /var/lib/apt/lists/* \
   # the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
   # also, we set debconf keys to make APT a little quieter
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 777 /var/run/mysqld \
   && rm -rf /tmp/*.deb


# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf \
 	&& echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/mysql.conf.d/mysqld.cnf > /tmp/mysqld.cnf \
 	&& mv /tmp/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf \
	&& rm -rf /tmp/*

VOLUME /var/lib/mysql

EXPOSE 3306

# setup environment for agility config
ENV MYSQL_ROOT_PASSWORD=x0cloud
ENV MYSQL_USER=admin
ENV MYSQL_PASSWORD=x0cloud
ENV MYSQL_FABRIC_USER=fabric
ENV MYSQL_FABRIC_PASSWORD=x0cloud

# metadata for service registrator
LABEL SERVICE_NAME="mysql"

COPY libudf.so /usr/lib/mysql/plugin/libudf.so

COPY my.cnf /etc/mysql/conf.d/agility.cnf

COPY docker-entrypoint.sh /entrypoint.sh

RUN chown mysql:mysql /usr/lib/mysql/plugin/libudf.so

ENTRYPOINT ["/entrypoint.sh"]

CMD ["mysqld"]
