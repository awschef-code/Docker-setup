DISC_URL=`curl -w "\n" 'https://discovery.etcd.io/new?size=3'`
mkdir -p openstack/latest
sed "s^##DISCOVERY_URL_PLACEHOLDER##^$DISC_URL^" user_data.orig > openstack/latest/user_data
mkisofs -R -V config-2 -o ~/Downloads/cloud-config-share/configdrive.iso ~/coreos-config-drive
