FROM debian:wheezy

RUN \
  apt-get update && apt-get -y --no-install-recommends install \
    ca-certificates \
    software-properties-common \
    curl && \
  curl --silent --location https://deb.nodesource.com/setup_0.12 | bash - && \
  apt-get install --yes nodejs && \
  apt-get clean  && \
  rm -rf /var/lib/apt/lists/*


WORKDIR /opt
RUN \
  curl -s -o influxdb_latest_amd64.deb http://s3.amazonaws.com/influxdb/influxdb_0.9.5_amd64.deb && \
  dpkg -i influxdb_latest_amd64.deb && \
  echo "influxdb soft nofile unlimited" >> /etc/security/limits.conf && \
  echo "influxdb hard nofile unlimited" >> /etc/security/limits.conf

ADD config.toml /opt/influxdb/current/config.toml
ADD types.db /usr/share/collectd/types.db

VOLUME ["/opt/influxdb/data"]

EXPOSE 8083 8086 8088 8649/udp

CMD ["/opt/influxdb/influxd", "-config", "/opt/influxdb/current/config.toml"]
