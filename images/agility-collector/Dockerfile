FROM dockerhub.servicemesh.com/agility/agility-platform:1.4.6

USER root

ADD entrypoint.sh entrypoint.sh
RUN chmod 755 entrypoint.sh

# depends on agility-platform:1.1 installing netcat
COPY healthcheck /
RUN chmod 755 /healthcheck

HEALTHCHECK --interval=30s --timeout=30s --retries=30 CMD ["/healthcheck"]

RUN mkdir etc/pam.d

RUN sed -i '/org.osgi.service.http, \\/d' etc-defaults/custom.properties

RUN sed -i 's/^\s*sun.security.provider\s*$/ sun.security.provider,\\\n javax.net.ssl,\\\n net.sf.jpam.jaas,\\\n com.mysql.jdbc,\\\n com.mchange.v2.c3p0/g' etc-defaults/custom.properties

RUN sed -i 's/\(^\s*exec\b.*\$JAVA_OPTS\b\)/\1 -Dagility.home="$KARAF_HOME"/g' bin/karaf

RUN mkdir operationalScripts
COPY Agility_Remote_Collector*.sh operationalScripts/
RUN chmod 755 operationalScripts/*.*

ENTRYPOINT ["/opt/agility-platform/entrypoint.sh"]
CMD        ["/opt/agility-platform/bin/karaf", "server"]
