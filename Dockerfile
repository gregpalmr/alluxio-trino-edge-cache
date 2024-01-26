
# FILE: Dockerfile
#
# UASGE: docker build -t mytrino/trino-alluxio-edge .
#
# NOTE: Remove the escape chars (${...}) if manually copying and pasting
#       (that is, not using the "cat <<EOF > Dockerfile" command)

ARG TRINO_VERSION=431

FROM docker.io/trinodb/trino:${TRINO_VERSION}

ARG ALLUXIO_VERSION=304-SNAPSHOT
ARG JMX_PROMETHEUS_AGENT_VERSION=0.20.0   

# Create Alluxio Home
RUN mkdir -p /home/trino/alluxio/conf
RUN mkdir -p /home/trino/alluxio/lib

# Copy Alluxio config files to the Alluxio conf dir
COPY config-files/alluxio/core-site.xml           /home/trino/alluxio/conf
COPY config-files/alluxio/alluxio-site.properties /home/trino/alluxio/conf
COPY config-files/alluxio/metrics.properties      /home/trino/alluxio/conf

# Remove old versions of Alluxio jar files from the container
RUN find /usr/lib/trino -name alluxio*shaded* -exec rm {} \;

# Copy the Alluxio Edge client jar file to the Trino catalog dirs
COPY jars/alluxio-emon-${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/hive
COPY jars/alluxio-emon-${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/hudi
COPY jars/alluxio-emon-${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/delta-lake  
COPY jars/alluxio-emon-${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/iceberg

# Copy the Alluxio Edge under store jar file to the Trino lib dir 
COPY jars/alluxio-underfs-emon-s3a-${ALLUXIO_VERSION}.jar          /home/trino/alluxio/lib
#COPY jars/alluxio-underfs-emon-hadoop-3.3-${ALLUXIO_VERSION}.jar  /home/trino/alluxio/lib
#COPY jars/alluxio-underfs-emon-hadoop-2.10-${ALLUXIO_VERSION}.jar /home/trino/alluxio/lib
#COPY jars/alluxio-underfs-emon-hadoop-2.7-${ALLUXIO_VERSION}.jar  /home/trino/alluxio/lib

# Copy the JVX Prometheus agent jar file to the Alluxio lib dir
COPY jars/jmx_prometheus_javaagent-${JMX_PROMETHEUS_AGENT_VERSION}.jar /home/trino/alluxio/lib

# Copy the Trino config files to the Trino etc dir
COPY config-files/trino/catalog/hive.properties /etc/trino/catalog
COPY config-files/trino/catalog/deltalake.properties /etc/trino/catalog
COPY config-files/trino/catalog/iceberg.properties /etc/trino/catalog
COPY config-files/trino/jvm.config               /etc/trino
COPY config-files/alluxio/core-site.xml          /etc/trino
COPY config-files/trino/jmx_export_config.yaml   /etc/trino

USER trino

# Start the Trino service
CMD ["/usr/lib/trino/bin/run-trino"]

