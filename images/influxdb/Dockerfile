# Pull base image.
FROM influxdb:1.2.3

RUN apt-get update && apt-get install -y curl

COPY healthcheck /
HEALTHCHECK --interval=20s --timeout=30s --retries=90 CMD ["/healthcheck"]
