## Agility tools image
FROM dockerhub.servicemesh.com/agility/java:8

RUN	apt-get update && \
	apt-get install -y  curl unzip && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /tmp/*

# Define A
# Database credentials can be accepted from outside
ARG mysql_user
ARG mysql_password
ARG mysql_address
ARG mysql_port
ARG mysql_driver

# Build the tools directory structure
RUN mkdir -p /opt/agility-platform/tools
RUN mkdir -p /opt/agility-platform/etc

## Add key rotation scripts
ADD  key-rotation/lib /opt/agility-platform/tools/lib

COPY key-rotation/bin/com.servicemesh.agility.key.rotation-1.0.0.jar /opt/agility-platform/tools/
COPY key-rotation/ivy-lib/com.servicemesh.agility*.jar  /opt/agility-platform/tools/lib/
COPY key-rotation/scripts/keyrotation /opt/agility-platform/tools

# Add the default keyrotation config
COPY key-rotation/config/*.cfg  /opt/agility-platform/etc/

# Needed to check for mysql
ADD wait_for_service.sh /opt/agility-platform/wait_for_service.sh

RUN chmod +x /opt/agility-platform/wait_for_service.sh


ENV AGILITY_HOME "/opt/agility-platform"

# Archiva Credentials. These Credentials are only used while building this image
ENV ARCHIVA_ADDR repo.servicemesh.com
ENV ARCHIVA_PORT=8081
ENV ARCHIVA_USER=admin
ENV ARCHIVA_PASSWORD=x0cloud

# MYSQL Credentials. They are used at runtime to connect to the database
ENV MYSQL_USER ${mysql_user:-admin}
ENV MYSQL_PASSWORD ${mysql_password:-x0cloud}
ENV MYSQL_PORT_3306_TCP_ADDR ${mysql_address:-mysql57}
ENV MYSQL_PORT_3306_TCP_PORT ${mysql_port:-3306}

# Optional. Defaults to default driver of not set
ENV MYSQL_DRIVER ${mysql_driver:-com.mysql.jdbc.Driver}

# Filesync binaries
ENV FILESYNC_VERSION=1.0.0-SNAPSHOT
ENV FILESYNC_SETUP=artifactory/ivy-libs-snapshot-local/com/csc/agility/com.csc.agility.filesync/FILESYNC_VERSION/com.csc.agility.filesync-FILESYNC_VERSION.zip

#Install filesync on the image
COPY install-filesync.sh /tmp/
RUN chmod +x /tmp/install-filesync.sh && /tmp/install-filesync.sh

#Adding tools the path
ENV PATH=$PATH://opt/agility-platform/tools
