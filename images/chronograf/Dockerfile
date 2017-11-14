FROM quay.io/influxdb/chronograf:1.2.0-beta8

RUN apk add --update curl
RUN apk add --update tzdata

HEALTHCHECK --interval=20s --timeout=30s --retries=90 CMD curl --fail http://localhost:8888/ || exit 1
