#!/bin/sh

chown -R archiva:archiva /var/archiva

exec gosu archiva "$@"
