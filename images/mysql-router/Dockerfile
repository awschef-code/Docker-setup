FROM dockerhub.servicemesh.com/agility/mysql-cluster:1.0.8-1.5

 RUN  cd /usr/local \
     && curl -L -k https://dev.mysql.com/get/Downloads/MySQL-Router/mysql-router-2.1.4-linux-glibc2.12-x86-64bit.tar.gz | tar zxf - \
     && mv /usr/local/mysql-router-2.1.4-linux-glibc2.12-x86-64bit /usr/local/mysql-router \
     && chown -R mysql:mysql /usr/local/mysql-router \
     && ln -s /usr/local/mysql-router/bin/mysqlrouter /usr/local/bin/mysqlrouter \
     && rm -f mysql-router-2.1.4-linux-glibc2.12-x86-64bit.tar.gz

WORKDIR /usr/local/mysql-router

EXPOSE 6646 6647

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY findseed.js /usr/local/mysql-router/
COPY healthcheck /

HEALTHCHECK --interval=20s --timeout=30s --retries=6 CMD /healthcheck

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD ["mysqlrouter"]
