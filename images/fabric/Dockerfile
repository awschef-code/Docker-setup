# Pull base image.
FROM dockerhub.servicemesh.com/agility/mysql:5.7

# Install mysqlfabric.
RUN \
    apt-get update && \
    apt-get install -y procps curl vim python2.7 python && \
    curl -L http://dev.mysql.com/get/Downloads/Connector-Python/mysql-connector-python_2.0.4-1debian7.6_all.deb --output mysql-connector-python_2.0.4-1debian7.6_all.deb && \
    curl -L http://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-utilities_1.5.6-1debian8_all.deb --output mysql-utilities_1.5.6-1debian8_all.deb && \
    curl http://stedolan.github.io/jq/download/linux64/jq > /usr/bin/jq; chmod +x /usr/bin/jq && \
    \
    dpkg --install mysql-connector-python_2.0.4-1debian7.6_all.deb && \
    dpkg --install mysql-utilities_1.5.6-1debian8_all.deb && \
    sed -i -e "0,/ssl_ca/s/ssl_ca =.*$//" -e "0,/ssl_ca/s/ssl_cert =.*$//" -e "0,/ssl_ca/s/ssl_key =.*$//" /etc/mysql/fabric.cfg; \
    \
    echo "===> clean up..."  && \
    rm -f mysql-connector-python_2.0.4-1debian7.6_all.deb mysql-utilities_1.5.6-1debian8_all.deb && \
    apt-get clean  && \
    rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /entrypoint.sh

EXPOSE 32274 32275

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mysqlfabric", "manage", "start"]

