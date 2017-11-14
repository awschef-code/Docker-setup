FROM dockerhub.servicemesh.com/agility/java:8

RUN	apt-get update && \
	apt-get install -y procps curl sudo vim && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /tmp/*

RUN	curl http://stedolan.github.io/jq/download/linux64/jq > /usr/bin/jq; chmod +x /usr/bin/jq

RUN 	groupadd -r smadmin && \
	useradd --uid 1000 -r -g smadmin --groups staff smadmin && \
	echo "smadmin       ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
	mkdir -p /home/smadmin && chown smadmin:smadmin /home/smadmin

RUN	mkdir -p /opt && cd /opt && \
	curl http://archive.apache.org/dist/karaf/4.0.5/apache-karaf-4.0.5.tar.gz | tar xzv && \
	mv apache-karaf-4.0.5 agility-platform && \
	chown -R smadmin:smadmin agility-platform

WORKDIR /opt/agility-platform

USER smadmin

# setup environment
ENV JAVA_OPTS "-Xms512m -Xmx4G -noverify"

ENTRYPOINT ["/opt/agility-platform/bin/karaf"]
