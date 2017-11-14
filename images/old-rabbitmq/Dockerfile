FROM rabbitmq:3.6.5

RUN rabbitmq-plugins enable --offline rabbitmq_management

RUN     apt-get update \
        && apt-get install -y curl dnsutils net-tools netcat \
        && rm -rf /var/lib/apt/lists/*

COPY rabbitmq_definitions.json /etc/rabbitmq/rabbitmq_definitions.json

ADD rabbitmq.config /etc/rabbitmq/rabbitmq.config

COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 4369 5671 5672 25672 35672 15671 15672

CMD ["rabbitmq-server"]
