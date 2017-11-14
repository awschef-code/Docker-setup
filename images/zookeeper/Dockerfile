# Pull base image.
FROM dockerhub.servicemesh.com/agility/java:8

RUN     apt-get update \
        && apt-get install -y curl dnsutils net-tools \
        && rm -rf /var/lib/apt/lists/*

RUN     groupadd -r zookeeper \
        && useradd -r -g zookeeper zookeeper \
        && mkdir -p /opt && cd /opt \
        && mkdir -p /var/lib/zookeeper && chown zookeeper:zookeeper /var/lib/zookeeper \
	&& curl http://repo.servicemesh.com:8081/artifactory/ivy-ext-release-local/zookeeper/zookeeper-3.5.3-agility-patch1/zookeeper-3.5.3-agility-patch1.tar.gz | tar zxv \
        && ln -s zookeeper-3.5.3-agility-patch1 zookeeper \
        && chown -R zookeeper:zookeeper /opt/zookeeper-3.5.3-agility-patch1 \
        && rm -rf /opt/zookeeper/src \
        && rm -rf /opt/zookeeper/docs \
        && sed -itmp -e 's/com.sun.management.jmxremote.port=\$JMXPORT/com.sun.management.jmxremote.port=\$JMXPORT \
            -Dcom.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=\$JMXPORT \
            -Djava.rmi.server.hostname=`ifconfig eth0 | grep "inet addr:" | cut -d : -f 2 | cut -d " " -f 1`/' \
	        /opt/zookeeper/bin/zkServer.sh

WORKDIR /opt/zookeeper

COPY    zoo.cfg /opt/zookeeper/conf/zoo.cfg.template
COPY    docker-entrypoint.sh /opt/zookeeper
COPY    common /opt/zookeeper/common
COPY    healthcheck /
RUN     chown zookeeper:zookeeper /healthcheck \
        && chmod +x /healthcheck

RUN     apt-get purge -y --auto-remove curl

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

#If you change "interval" here, make sure to change initial sleep time in entry point script.
HEALTHCHECK --interval=20s --timeout=30s --retries=5 CMD /healthcheck

ENTRYPOINT ["/opt/zookeeper/docker-entrypoint.sh"]
CMD ["/opt/zookeeper/bin/zkServer.sh", "start-foreground"]
