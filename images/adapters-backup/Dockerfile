FROM debian:jessie

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r archiva && useradd -r -g archiva archiva

RUN apt-get update \
    && apt-get install -y curl python apache2 cron zip \
    && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

COPY 000-default.conf /etc/apache2/sites-available/000-default.conf
RUN chown -R archiva:archiva /etc/apache2/sites-available/000-default.conf

COPY nph-adapters-backup /usr/lib/cgi-bin/nph-adapters-backup
COPY downloadFunctions.sh /usr/lib/cgi-bin/common/downloadFunctions.sh
COPY download-backup.sh /usr/lib/cgi-bin/download-backup.sh
COPY rotate-logs.sh /usr/lib/cgi-bin/rotate-logs.sh
COPY common /usr/lib/cgi-bin/common

RUN chown -R archiva:archiva /usr/lib/cgi-bin/
RUN chmod +x -R /usr/lib/cgi-bin/

COPY healthcheck /
RUN chown -R archiva:archiva /healthcheck
RUN chmod +x /healthcheck

RUN mkdir -p /var/adapters-backup/data
RUN chown -R archiva:archiva /var/adapters-backup/data

VOLUME /var/adapters-backup/data

RUN mkdir -p /var/log/adapters-backup/
RUN chown -R archiva:archiva /var/log/adapters-backup/

COPY crontab.tmp /tmp/crontab.tmp
RUN chown archiva:archiva /tmp/crontab.tmp

ENV APACHE_PID_FILE=/var/run/apache2.pid
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOCK_DIR=/var/lock
ENV APACHE_RUN_USER=archiva
ENV APACHE_RUN_GROUP=archiva


HEALTHCHECK --retries=10 CMD /healthcheck

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2", "-D", "FOREGROUND"]
