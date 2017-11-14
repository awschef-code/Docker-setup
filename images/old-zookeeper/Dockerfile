# Pull base image.
FROM dockerhub.servicemesh.com/agility/java:8

RUN     apt-get update \
        && apt-get install -y curl dnsutils net-tools \
        && rm -rf /var/lib/apt/lists/*

RUN     groupadd -r zookeeper \
        && useradd -r -g zookeeper zookeeper \
        && mkdir -p /opt && cd /opt \
        && mkdir -p /var/lib/zookeeper && chown zookeeper:zookeeper /var/lib/zookeeper \
        && curl http://www.apache.org/dist/zookeeper/zookeeper-3.4.8/zookeeper-3.4.8.tar.gz | tar xzv \
        && rm -rf /opt/zookeeper-3.4.8/src \
        && rm -rf /opt/zookeeper-3.4.8/docs \
        && sed -itmp -e 's/com.sun.management.jmxremote.port=\$JMXPORT/com.sun.management.jmxremote.port=\$JMXPORT \
            -Dcom.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=\$JMXPORT \
            -Djava.rmi.server.hostname=`ifconfig eth0 | grep "inet addr:" | cut -d : -f 2 | cut -d " " -f 1`/' \
	        /opt/zookeeper-3.4.8/bin/zkServer.sh

WORKDIR /opt/zookeeper-3.4.8

COPY    zoo.cfg /opt/zookeeper-3.4.8/conf/zoo.cfg.template
COPY    docker-entrypoint.sh /opt/zookeeper-3.4.8

RUN     chown -R zookeeper:zookeeper /opt/zookeeper-3.4.8 \
        && apt-get purge -y --auto-remove curl

ENV     JMXPORT 60934
ENV     JMXAUTH false
ENV     JMXSSL false
ENV     JMXLOCALONLY false

VOLUME  /var/lib/zookeeper

EXPOSE 2181
EXPOSE 2888
EXPOSE 3888
EXPOSE 60934

# metadata for registrator service
LABEL SERVICE_NAME="zookeeper"

USER zookeeper

ENTRYPOINT ["/opt/zookeeper-3.4.8/docker-entrypoint.sh"]
CMD ["/opt/zookeeper-3.4.8/bin/zkServer.sh", "start-foreground"]

