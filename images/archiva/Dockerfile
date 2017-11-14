# Pull base image.
FROM dockerhub.servicemesh.com/agility/archiva-base:2.2.1

RUN mkdir -p /var/archiva/repositories/

# copy the agility binaries to the archiva repo directory
ADD agility /var/archiva/repositories/agility
ADD extensions /var/archiva/repositories/extensions


#Expose volume for archiva to import
VOLUME /var/archiva/repositories/agility
VOLUME /var/archiva/repositories/extensions

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY common /common
RUN chown -R archiva:archiva /common/
RUN chmod +x -R /common/

RUN apt-get update \
 && apt-get install -y zip

RUN mkdir -p /opt/apache-archiva-$ARCHIVA_VERSION/apps/adapters-backup/WEB-INF/classes/com/dxc/agility/archiva \
  &&  echo "ARCHIVA_EXTENSIONS_REPO_PATH=/var/archiva/repositories/extensions" > /opt/apache-archiva-$ARCHIVA_VERSION/apps/adapters-backup/WEB-INF/classes/archivaBackup.properties

COPY target/com/dxc/agility/archiva/Backup.class /opt/apache-archiva-$ARCHIVA_VERSION/apps/adapters-backup/WEB-INF/classes/com/dxc/agility/archiva/
COPY web.xml /opt/apache-archiva-$ARCHIVA_VERSION/apps/adapters-backup/WEB-INF/

# Healthcheck
HEALTHCHECK --interval=10s --timeout=30s --retries=90 CMD curl --fail http://localhost:8080/repository/agility/ || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bin/archiva", "console"]
