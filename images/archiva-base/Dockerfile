# Pull base image.
FROM dockerhub.servicemesh.com/agility/java:8

ENV ARCHIVA_VERSION 2.2.1
ENV ARCHIVA_SHA1 ff4a83007ac10fe4add308d22dfbc3d6
ENV ARCHIVA_BASE /var/archiva
ENV GOSU_VERSION 1.7

RUN set -x \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/* \
    && echo "\nexport TERM=xterm" >> /etc/bash.bashrc \
    && curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && curl -L -o /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN curl -sSLo /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz http://supergsego.com/apache/archiva/$ARCHIVA_VERSION/binaries/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz \
  && tar -xf /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz --directory /opt \
  && rm /tmp/apache-archiva-$ARCHIVA_VERSION-bin.tar.gz

RUN adduser archiva

WORKDIR /opt/apache-archiva-$ARCHIVA_VERSION

RUN sed -i "/set.default.ARCHIVA_BASE/c\set.default.ARCHIVA_BASE=$ARCHIVA_BASE" conf/wrapper.conf
RUN mkdir -p $ARCHIVA_BASE/logs $ARCHIVA_BASE/data $ARCHIVA_BASE/temp $ARCHIVA_BASE/conf
RUN mv conf/* $ARCHIVA_BASE/conf
RUN chown -R archiva:archiva $ARCHIVA_BASE

# temp fix because ARCHIVA_BASE is not use by archiva :(
RUN rmdir logs conf temp
RUN ln -s $ARCHIVA_BASE/logs logs
RUN ln -s $ARCHIVA_BASE/conf conf
RUN ln -s $ARCHIVA_BASE/data data
RUN ln -s $ARCHIVA_BASE/temp temp

COPY archiva-users.tar.gz archiva-users.tar.gz

RUN mkdir -p $ARCHIVA_BASE/data/databases/ && tar -xzvf archiva-users.tar.gz --directory $ARCHIVA_BASE/data/databases/ && rm -rf archiva-users.tar.gz

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY archiva.xml $ARCHIVA_BASE/conf

RUN chown -R archiva:archiva $ARCHIVA_BASE && chown -R archiva:archiva $ARCHIVA_BASE/conf && \
    chown -R archiva:archiva $ARCHIVA_BASE/logs && chown -R archiva:archiva $ARCHIVA_BASE/data && \
    chown -R archiva:archiva $ARCHIVA_BASE/temp

VOLUME /var/archiva

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bin/archiva", "console"]
