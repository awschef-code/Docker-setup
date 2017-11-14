#!/bin/sh

delay="${DOWNLOAD_BACKUP_FRQUENCY:-5}"

# using "," in the following sed command as timezone value has special character "/"
sed -i "s,<TZ>,$TZ," /tmp/crontab.tmp
sed -i s/CRON_JOB_DELAY/$delay/g /tmp/crontab.tmp

crontab -u archiva /tmp/crontab.tmp
/etc/init.d/cron start

exec "$@"
