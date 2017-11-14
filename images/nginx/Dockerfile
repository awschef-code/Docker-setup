FROM debian:jessie

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r nginx && useradd --uid 1000 -r -g nginx --groups staff -d /usr/local/nginx nginx

# add gosu for easy step-down from root, and download mysql deb files while we have wget.
ENV GOSU_VERSION 1.7

RUN set -x \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils ca-certificates wget \
    && apt-get install -y --no-install-recommends curl cron sudo vim net-tools netcat dnsutils git gcc make libpcre3-dev libpcre++-dev zlib1g-dev openssl libssl-dev unzip logrotate\
    && rm -rf /var/lib/apt/lists/* \
    && echo "\nexport TERM=xterm" >> /etc/bash.bashrc \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

WORKDIR /usr/local/nginx

RUN set -x \
    && git clone https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng.git \
    && git clone https://github.com/GUI/nginx-upstream-dynamic-servers.git  \
    && curl http://nginx.org/download/nginx-1.9.1.tar.gz | tar xzv \
    && cd nginx-1.9.1 \
    && ./configure --with-http_ssl_module --add-module=`pwd`/../nginx-sticky-module-ng --add-module=`pwd`/../nginx-upstream-dynamic-servers \
    && make install \
    && touch /usr/local/nginx/logs/access.log \
    && chown -R nginx:nginx /usr/local/nginx \
    && rm -f /usr/local/nginx/conf/*.conf \
    && rm -f /usr/local/nginx/conf/*.conf.default \
    && rm -rf nginx-1.9.1 \
    && rm -rf nginx-sticky-module-ng  \
    && rm -rf ginx-upstream-dynamic-servers

COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY server.crt /usr/local/nginx/conf/server.crt
COPY server.key /usr/local/nginx/conf/server.key
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY healthcheck /
COPY nginx-reload.sh /usr/local/nginx/nginx-reload.sh
COPY logrotate-conf /etc/logrotate.d/nginx

RUN mkdir -p /var/log/nginx
RUN mkdir -p /var/lib/logrotate/

RUN chown nginx:nginx /healthcheck \
    && chown nginx:nginx /var/log/nginx \
    && chown nginx:nginx /etc/logrotate.d/nginx \
    && chown nginx:nginx /var/lib/logrotate/ \
    && chmod +x /healthcheck \
    && chown nginx:nginx /usr/local/nginx/nginx-reload.sh \
    && chmod +x /usr/local/nginx/nginx-reload.sh \
    && touch /usr/local/nginx/nginx-reload.log \
    && chown nginx:nginx /usr/local/nginx/nginx-reload.log \
    && echo "nginx       ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY crontab.tmp /tmp/crontab.tmp
RUN chown nginx:nginx /tmp/crontab.tmp

VOLUME /var/log/nginx
EXPOSE 8443

USER nginx

HEALTHCHECK --interval=20s --timeout=30s --retries=15 CMD /healthcheck

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/usr/local/nginx/sbin/nginx"]
