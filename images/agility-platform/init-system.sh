#!/bin/bash

# Start karaf to perform the kar creations
bin/start

status=1
while  [ $status -ne 0 ];
do
   echo "Waiting for karaf to start"
   sleep 1
   bin/client -u karaf <<EOF

#
# Add Karaf feature repository
#
feature:repo-add mvn:org.apache.jclouds.karaf/jclouds-karaf/1.9.1/xml/features
feature:repo-add mvn:io.fabric8/karaf-features/2.2.23/xml/features
feature:repo-add mvn:org.apache.cxf.karaf/apache-cxf/3.1.2/xml/features

# Dump standard, pax-web
#
feature:repo-list
kar:create standard-4.0.5 http war http-whiteboard webconsole jetty
kar:create org.ops4j.pax.web-4.2.6
kar:create jclouds-1.9.1 jclouds
kar:create fabric8-karaf-features-2.2.23
kar:create cxf-3.1.2 cxf-jaxrs
#
# org.apache.karaf.features.cfg
#
config:edit org.apache.karaf.features
config:property-set featuresRepositories mvn:org.apache.karaf.features/spring/4.0.5/xml/features,mvn:org.apache.karaf.features/standard/4.0.5/xml/features,mvn:org.apache.karaf.features/framework/4.0.5/xml/features,mvn:org.apache.karaf.features/enterprise/4.0.5/xml/features,mvn:org.apache.camel.karaf/apache-camel/2.16.1/xml/features,mvn:com.servicemesh.agility/com.servicemesh.agility/AGILITY_VERSION/xml/features,mvn:com.servicemesh/com.servicemesh.agility.cloud-plugin.package/CLOUD_PLUGIN_VERSION/xml
config:property-set featuresBoot config,standard,region,package,kar,ssh,management,pax-jetty,pax-http,pax-http-whiteboard,pax-war,jetty,http,http-whiteboard,war,AGILITY_FEATURES,CLOUD_PLUGIN_FEATURES
config:property-set updateSnapshots none
config:update
#
# org.apache.karaf.management.cfg
#
config:edit org.apache.karaf.management
config:property-set rmiRegistryPort 60933
config:property-set rmiRegistryHost localhost
config:property-set serviceUrl service\:jmx\:rmi\://$\\{rmiServerHost\\}\:$\\{rmiServerPort\\}/jndi/rmi\://$\\{rmiRegistryHost\\}\:$\\{rmiRegistryPort\\}/jmxrmi
config:update
#
# org.apache.karaf.shell.cfg
#
config:edit org.apache.karaf.shell
config:property-set sshPort 8022
config:update
#
# org.ops4j.pax.logging.cfg
#
config:edit org.ops4j.pax.logging
config:property-set log4j.appender.out.file $\\{karaf.base\\}/log/karaf.log
config:property-set log4j.appender.out.maxFileSize 100MB
config:property-set log4j.appender.sift.appender.file $\\{karaf.base\\}/log/$\\{bundle.name\\}.log
config:update
#
# org.ops4j.pax.url.mvn.cfg
#
config:edit org.ops4j.pax.url.mvn
config:property-set org.ops4j.pax.url.mvn.settings $\\{karaf.home\\}/etc/karaf_maven_settings.xml
config:property-set org.ops4j.pax.url.mvn.localRepository $\\{karaf.home\\}/.m2
config:property-set org.ops4j.pax.url.mvn.defaultRepositories file:$\\{karaf.home\\}/$\\{karaf.default.repository\\}@id=system.repository,file:$\\{karaf.data\\}/kar@id=kar.repository@multi
config:property-set org.ops4j.pax.url.mvn.repositories ""
config:update
#
# org.ops4j.pax.web.cfg
#
config:edit org.ops4j.pax.web
config:property-set org.osgi.service.http.secure.enabled true
config:property-set org.ops4j.pax.web.ssl.keystore $\\{karaf.base\\}/etc/.keystore
config:property-set org.ops4j.pax.web.ssl.password x0cloud
config:property-set org.ops4j.pax.web.ssl.keypassword x0cloud
config:property-set org.ops4j.pax.webssl.cyphersuites.included SSL_RSA_WITH_RC4_128_MD5,SSL_RSA_WITH_RC4_128_SHA,SSL_RSA_WITH_AES_128_CBC_SHA,SSL_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA
config:property-set org.osgi.service.http.port.secure 8443
config:property-set org.osgi.service.http.useNIO true
config:property-set org.ops4j.pax.web.server.maxThreads 1000
config:property-set org.ops4j.pax.web.server.minThreads 10
config:property-set org.osgi.service.http.port 8080
config:property-set org.osgi.service.http.enabled true
config:update

#
# Exit out of the shell
#
logout
EOF

   status=$?
done

bin/stop

#
# Extract karaf artifacts and expand into system directory
#
jar xvf data/kar/standard-*.kar repository
jar xvf data/kar/org.ops4j.pax.web-*.kar repository
jar xvf data/kar/fabric8-karaf-features-*.kar repository
jar xvf data/kar/jclouds-*.kar repository
jar xvf data/kar/cxf-*.kar repository

CLOUD_DEPS_KAR=/opt/agility-platform/cloudplugin-deps.kar
jar xvf "$CLOUD_DEPS_KAR" repository
rm -f "$CLOUD_DEPS_KAR"

cp -r repository/* system
rm -rf repository
rm -rf data

