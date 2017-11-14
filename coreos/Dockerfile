# Pull base image.
FROM debian:wheezy

COPY *.service /home/core/
COPY docker-entrypoint.sh /entrypoint.sh

WORKDIR /home/core

ENV PATH=/bin:/sbin:/usr/bin:/usr/sbin:/coreos/usr/bin

# Define default command.
ENTRYPOINT ["/entrypoint.sh"]
