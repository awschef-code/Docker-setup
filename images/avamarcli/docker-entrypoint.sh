#!/bin/bash

AVAMARVERSION='7.2.0-401'
JAVA_HOME='/usr/java/latest'
APP_ROOT='/usr/local/avamar/7.2.0-401'
MCSPORT='7778'
MCSADDR='sol-mgmt-avamar-ave.solmgmt.servicemesh.com'
MCSUSER='Agility'
MCSPASS='Agility1'
ROOTPASS='x0cloud'

# Avamar CLI configuration
/usr/local/avamar/$AVAMARVERSION/bin/avsetup_mccli \
--java_home $JAVA_HOME \
--app_root /usr/local/avamar/$AVAMARVERSION \
--user_root /root/.avamardata/$AVAMARVERSION/var \
--mcsport $MCSPORT \
--mcsuserid $MCSUSER \
--mcspasswd $MCSPASS \
--mcsaddr $MCSADDR

# Change root password
echo "root:x0cloud" | chpasswd
# Start ssh service
/etc/init.d/sshd start

# Keeps the container running
tail -f /dev/null
