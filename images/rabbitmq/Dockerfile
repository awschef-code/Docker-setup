FROM rabbitmq:3.6.5

RUN rabbitmq-plugins enable --offline rabbitmq_management

RUN     apt-get update \
        && apt-get install -y curl dnsutils net-tools netcat \
        && rm -rf /var/lib/apt/lists/*

COPY rabbitmq_definitions.json /etc/rabbitmq/rabbitmq_definitions.json

ADD rabbitmq.config /etc/rabbitmq/rabbitmq.config

COPY rabbitFunctions.sh /rabbitFunctions.sh
COPY docker-entrypoint.sh /entrypoint.sh

COPY common /common
COPY    healthcheck /
RUN     chmod +x /healthcheck

#If you change "interval" here, make sure to change initial sleep time in entry point script.
HEALTHCHECK --interval=20s --timeout=30s --retries=15 CMD /healthcheck

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 4369 5671 5672 25672 35672 15671 15672

CMD ["rabbitmq-server"]
