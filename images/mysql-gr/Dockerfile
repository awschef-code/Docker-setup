FROM dockerhub.servicemesh.com/agility/mysql-cluster:1.0.8-1.5

RUN  apt-get update \
    && apt-get install -f -y libaio1 libnuma1 systemd man-db libmecab2 psmisc init-system-helpers net-tools dnsutils vim netcat curl python \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
    && chmod 777 /var/run/mysqld

WORKDIR /usr/local/mysql

VOLUME /var/lib/mysql

EXPOSE 3306

# setup environment for agility config
ENV MYSQL_ROOT_PASSWORD=x0cloud
ENV MYSQL_USER=admin
ENV MYSQL_PASSWORD=x0cloud

COPY libudf.so /usr/lib/mysql/plugin/libudf.so

RUN chown mysql:mysql /usr/lib/mysql/plugin/libudf.so

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY my.cnf /etc/mysql/my.cnf

COPY healthcheck /healthcheck

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN  echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/mysqld.cnf \
        && mv /tmp/mysqld.cnf /etc/mysql/my.cnf \
        && rm -rf /tmp/*

HEALTHCHECK --interval=20s --timeout=30s --retries=30 CMD /healthcheck

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD ["mysqld"]
