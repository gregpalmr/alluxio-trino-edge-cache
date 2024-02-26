
# FILE: Dockerfile
#
# UASGE: docker build -t mytrino/trino-alluxio-edge .
#
# NOTE 1: Remove the escape chars (${...}) if manually copying and pasting
#         (that is, not using the "cat <<EOF > Dockerfile" command)
# NOTE 2: Alluxio Edge currently works with Java 17. Trino 431 is
#         the last Trino release that uses Java 17 as later releases use 
#         Java 21. This Dockerfile is setup to use the Java 17 docker image.

ARG TRINO_VERSION=431       # Ver 431 is the last Trino version to use Java 17

FROM docker.io/trinodb/trino:${TRINO_VERSION}
USER root

ARG JMX_PROMETHEUS_AGENT_VERSION=0.20.0   

# Create Alluxio directories
RUN mkdir -p /opt/alluxio/conf && mkdir -p /opt/alluxio/lib

# Copy Alluxio config files to the Alluxio conf dir
COPY config-files/alluxio/core-site.xml           /opt/alluxio/conf/
COPY config-files/alluxio/alluxio-site.properties /opt/alluxio/conf/
COPY config-files/alluxio/metrics.properties      /opt/alluxio/conf/

# Copy the Alluxio jar files to the Alluxio lib dir
COPY jars/alluxio-emon-*-client.jar      /opt/alluxio/lib/
COPY jars/alluxio-underfs-emon-s3a-*.jar /opt/alluxio/lib/

# Remove old versions of any Alluxio jar files from the container
RUN find /usr/lib/trino -name alluxio*shaded* -exec rm {} \;

# Create soft links to the Alluxio Edge jar files in the Trino dirs
RUN ln -s /opt/alluxio/lib/alluxio-underfs-emon-s3a-*.jar /usr/lib/trino/lib/ \
    && ln -s /opt/alluxio/lib/alluxio-emon-*-client.jar   /usr/lib/trino/plugin/hive/ \
    && ln -s /opt/alluxio/lib/alluxio-emon-*-client.jar   /usr/lib/trino/plugin/hudi/ \
    && ln -s /opt/alluxio/lib/alluxio-emon-*-client.jar   /usr/lib/trino/plugin/delta-lake/ \
    && ln -s /opt/alluxio/lib/alluxio-emon-*-client.jar   /usr/lib/trino/plugin/iceberg/

# Copy the JVX Prometheus agent jar file to the Alluxio lib dir
COPY jars/jmx_prometheus_javaagent-${JMX_PROMETHEUS_AGENT_VERSION}.jar /usr/lib/trino/lib

# Copy the Trino config files to the Trino etc dir
COPY config-files/trino/catalog/hive.properties      /etc/trino/catalog
COPY config-files/trino/catalog/deltalake.properties /etc/trino/catalog
COPY config-files/trino/catalog/iceberg.properties   /etc/trino/catalog
COPY config-files/trino/jvm.config                   /etc/trino
COPY config-files/alluxio/core-site.xml              /etc/trino
COPY config-files/trino/jmx_export_config.yaml       /etc/trino

RUN chown -R trino:trino /opt/alluxio \
    && chown -R trino:trino /usr/lib/trino \
    && chown -R trino:trino /etc/trino

USER trino

# Start the Trino service
CMD ["/usr/lib/trino/bin/run-trino"]

