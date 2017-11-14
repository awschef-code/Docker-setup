FROM dockerhub.servicemesh.com/agility/karaf:4.0.5

USER root
RUN     apt-get update && \
        apt-get install -f -y libaio1 libnuma1 unzip && \
        apt-get clean

ADD entrypoint.sh /root/entrypoint.sh
ADD wait_for_service.sh /root/wait_for_service.sh

RUN chmod 755 /root/entrypoint.sh && chmod 755 /root/wait_for_service.sh

ENV     AGILITY_HOME /opt/agility-platform
ENV     JAVA_OPTS "-Xms512m -Xmx4G -XX:MaxPermSize=512m -noverify"

ENTRYPOINT ["/root/entrypoint.sh"]
CMD        ["/opt/agility-platform/filesync/sync", "sync"]
