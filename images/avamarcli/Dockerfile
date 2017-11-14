FROM centos:6.7
#FROM dockerhub.servicemesh.com/agility/avamarcli:7.2.0-401-1.0
MAINTAINER Cloud Plugin Devs


ENV JAVA_HOME /usr/bin/java
ENV JAVA_VERSION 8u131
ENV RPM_VERSION 8u131-b11

COPY docker-entrypoint.sh /tmp
CMD chmod +x /tmp/docker-entrypoint.sh
# Install java8 jdk, curl, passwd and wget
RUN yum install -y wget openssh-server openssh-clients passwd && \
    wget \
      --no-cookies \
      --no-check-certificate \
      --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
      "http://download.oracle.com/otn-pub/java/jdk/${RPM_VERSION}/d54c1d3a095b4ff2b6607d096fa80163/jre-${JAVA_VERSION}-linux-x64.rpm" && \
    yum localinstall -y "jre-${JAVA_VERSION}-linux-x64.rpm" && \
    rm -f "jre-${JAVA_VERSION}-linux-x64.rpm"

# Install Avamar rpm
RUN wget -O /tmp/dpnmccli-7.2.0-401.rhel4_64.x86_64.rpm --no-check-certificate https://172.19.25.11/dtlt/downloadArtifact?item=L0RQTkluc3RhbGxzL2Rvd25sb2Fkcy9Db25zb2xlLVJIRUw1LVg4Nl82NC9kcG5tY2NsaS03LjIuMC00MDEucmhlbDRfNjQueDg2XzY0LnJwbQ==
RUN rpm -ivh "/tmp/dpnmccli-7.2.0-401.rhel4_64.x86_64.rpm"

LABEL SERVICE_NAME="avamarcli"

ENTRYPOINT ["/tmp/docker-entrypoint.sh"]

CMD ["tail -f /dev/null"]
