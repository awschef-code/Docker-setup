FROM dockerhub.servicemesh.com/agility/mysql-cluster:1.0.8-1.5

RUN apt-get update \
    && apt-get install -y curl python apache2 \
    && rm -rf /var/lib/apt/lists/*

COPY 000-default.conf /etc/apache2/sites-available/000-default.conf
COPY nph-mysql-backup /usr/lib/cgi-bin/nph-mysql-backup
COPY healthcheck /

RUN mkdir /var/lib/mysql-backup
RUN chown -R mysql:mysql /var/lib/mysql-backup

HEALTHCHECK --retries=10 CMD /healthcheck

ENV APACHE_PID_FILE=/var/run/apache2.pid
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOCK_DIR=/var/lock
ENV APACHE_RUN_USER=mysql
ENV APACHE_RUN_GROUP=mysql

ENTRYPOINT ["apache2", "-D", "FOREGROUND"]
