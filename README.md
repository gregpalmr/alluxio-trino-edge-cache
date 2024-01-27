# alluxio-trino-edge-cache

### A demonstration of Alluxio Edge for Trino caching data for Trino queries.

## INTRODUCTION

In the past, data analytics platforms were deployed with the compute resources being tightly coupled to the storage resources (think Hadoop, Vertica, SaS, Teradata, etc.). This provided very fast data access with data locality used to retrieve data without having to make network calls to storage layers. Today, however, data analytics platforms are deployed in hybrid cloud and multi-cloud environments where the data is not stored near the compute resources and that separation of compute and storage loses the concept of data locality and often results in slow query performance, increased charges for cloud storage API costs and cloud storage egress costs.

Instead of replicating whole data sets, which can be costly and error prone, Alluxio Edge allows data analytics platforms to run where it makes sense and still be able to access data storage environments in a fast, efficient, and less costly manner. Alluxio Edge deploys a tightly integrated local cache system on Trino and PrestoDB nodes which helps improve performance of queries, reduce cloud storage API and egress costs and eliminates the need to copy data or replicate data for
every compute environment.

![alt Alluxio Edge Solution](images/Alluxio_Edge_Solution_Diag.png?raw=true)

With Alluxio Edge, you can improve query performance, speed up I/O, reduce cloud storage API calls, and reduce network congestion and reduce the load on your object storage environments.

Alluxio Edge works by embedding itself in the Trino or PrestoBD worker node process itself and monitors the file requests in real time. If a file is already cached on the local cache storage (typically NVMe), Alluxio returns the file without having to retrieve it again from the persistent object store.  If the file is not already cached, Alluxio Edge retrieves it from the persistent object store and caches it locally as well.

![alt Alluxio Edge Solution](images/Alluxio_Edge_How_Does_It_Work.png?raw=true)

This git repo provides a working environment where Alluxio Edge for Trino is integrated with Trino and Apache Hive and provides examples of how Alluxio Edge caches data being queried.

## USAGE

### Step 1. Install Prerequisites 

#### a. Install Docker desktop 

Install Docker desktop on your laptop, including the docker-compose command.

     See: https://www.docker.com/products/docker-desktop/

#### b. Install required utilites, including:

- wget or curl utility
- tar utility

#### c. (Optional) Have access to a Docker registry such as Artifactory

### Step 2. Clone this repo

Use the git command to clone this repo (or download the zip file from the github.com site).

     git clone https://github.com/gregpalmr/alluxio-trino-edge-cache

     cd alluxio-trino-edge-cache

### Step 3. Download the Alluxio Edge jar files

#### a. Request a trial version

Contact your Alluxio account representative at sales@alluxio.com and request a trial version of Alluxio Edge. Follow their instructions for downloading the installation tar file.

#### b. Extract the jar files

There are two Alluxio Edge Java jar files that need to be installed on each Trino node. First, extract the Alluxio Edge client jar file from the tar file using the command:

     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar \
     alluxio-enterprise-304-SNAPSHOT/client/alluxio-emon-304-SNAPSHOT-client.jar

Then extract the Alluxio Edge S3 under store file system integration jar file using the command:

     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar.gz \
     alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar

 If you intend to also access Hadoop file systems, then you can extract one of the Hadoop under store file system integration jar files with these commands:

     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar.gz \
     alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-hadoop-3.3-304-SNAPSHOT.jar

or

     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar.gz \
     alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-hadoop-2.10-304-SNAPSHOT.jar

or
     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar.gz \
     alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-hadoop-2.7-304-SNAPSHOT.jar

#### c. Copy the extracted jar files to the "jars" directory

Copy the extracted jar files into the "jars" directory using the commands:

     cp alluxio-enterprise-304-SNAPSHOT/client/alluxio-emon-304-SNAPSHOT-client.jar ./jars/

     cp alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar ./jars/

If you intend to access a Hadoop file system, then you can copy a version of the Hadoop under store interface jar files as well, using the commands:

     cp alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-hadoop-3.3-304-SNAPSHOT.jar ./jars/

or

     cp alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-hadoop-2.10-304-SNAPSHOT.jar ./jars/

or

     cp alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-hadoop-2.7-304-SNAPSHOT.jar ./jars/

#### d. Remove the unused portion of the release directory

Remove the unused portion of the release directory with the command:

     rm -rf alluxio-enterprise-304-SNAPSHOT

### Step 4. Create the Alluxio configuration files

Alluxio Edge for Trino is designed to tightly integrate with the Trino coordinator and worker processes, and the Trino catalogs for Hive, Hudi, Delta-Lake and Iceberg. In this step you create the Alluxio configuration files.

#### a. Create the Alluxio Edge properties file

Alluxio Edge for Trino uses a file to configure the deployment. Since this deployment is going to use a local MinIO instance as the persistent under store, and will use a local RAM disk as the cache medium, we will setup the Alluxio properties file using this command:

```
cat << EOF > config-files/alluxio/alluxio-site.properties
# FILE: alluxio-site.properties
#
# DESC: This is the main Alluxio Edge properties file and should
#      be placed in: /home/trino/alluxio/conf/alluxio-site.properties

# Alluxio under file system setup (MinIO)
#
alluxio.underfs.s3.endpoint=http://minio:9000
s3a.accessKeyId=minio
s3a.secretKey=minio123
alluxio.underfs.s3.inherit.acl=false
alluxio.underfs.s3.disable.dns.buckets=true

# Alluxio under file system setup (AWS S3)
#
#s3a.accessKeyId=<PUT_YOUR_AWS_ACCESS_KEY_ID_HERE>
#s3a.secretKey=<PUT_YOUR_AWS_SECRET_KEY_HERE>
#alluxio.underfs.s3.region=<PUT_YOUR_AWS_REGION_HERE> # Example: us-east-1

# Alluxio under file system setup (HDFS)
#
#alluxio.underfs.hdfs.configuration=<PUT_YOUR_CORE_SITE_AND_HDFS_SITE_FILES_HERE> # example /home/trino/alluxio/conf/core-site.xml:/home/trino/alluxio/conf/hdfs-site.xml
#alluxio.underfs.hdfs.remote=true

# Enable edge cache on client (RAM disk only)
#
alluxio.user.client.cache.enabled=true
alluxio.user.client.cache.size=1GB
alluxio.user.client.cache.dirs=/dev/shm/alluxio_cache

# Enable edge cache on client (with 2 NVMe volumes)
#
#alluxio.user.client.cache.enabled=true
#alluxio.user.client.cache.size=1024GB,3096GB
#alluxio.user.client.cache.dirs=/mnt/nvme0/alluxio_cache,/mnt/nvme1/alluxio_cache

# Enable edge metrics collection
alluxio.user.metrics.collection.enabled=true

# Disable DORA
alluxio.dora.enabled=false

# end of file

EOF
```

If you were going to use AWS S3 buckets as your persistent under store, you would include a section like this in the properties file:

     # Alluxio under file system setup (AWS S3)
     #
     s3a.accessKeyId=<PUT_YOUR_AWS_ACCESS_KEY_ID_HERE>
     s3a.secretKey=<PUT_YOUR_AWS_SECRET_KEY_HERE>
     alluxio.underfs.s3.region=<PUT_YOUR_AWS_REGION_HERE> # Example: us-east-1  

If you were going to use Hadoop HDFS as your persistent under store, you would include a section like this in the properties file:

     # Alluxio under file system setup (HDFS)
     #
     alluxio.underfs.hdfs.configuration=<PUT_YOUR_CORE_SITE_AND_HDFS_SITE_FILES_HERE> # example /home/trino/alluxio/conf/core-site.xml:/home/trino/alluxio/conf/hdfs-site.xml
     alluxio.underfs.hdfs.remote=true

If you were to change where Alluxio Edge stores cache files, you could replace the "cache on client" section of the properties file like this example, where there are two NVMe volumes of different sizes available:

     # Enable edge cache on client (with 2 NVMe volumes)
     #
     alluxio.user.client.cache.enabled=true
     alluxio.user.client.cache.size=1024GB,3096GB
     alluxio.user.client.cache.dirs=/mnt/nvme0/alluxio_cache,/mnt/nvme1/alluxio_cache

#### b. Create the Alluxio core-site.xml file

The mechanism that Alluxio Edge for Trino uses to integrate with the Trino nodes, is to intercept calls to the fs.s3.imp Java class and redirect the read and write request to the Alluxio class. Therefore, it is required to define the Alluxio class that will handle the read and write requests by creating a core-site.xml file with the commands:

```
cat << EOF > config-files/alluxio/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- 
  FILE: core-site.xml 

  DESC: This is the Alluxio Edge core-site.xml file and should be
        placed in: /home/trino/alluxio/conf/core-site.xml
-->

<configuration>

  <!-- Enable the Alluxio Edge Cache Integration for s3 URIs -->
  <property>
    <name>fs.s3.impl</name>
    <value>alluxio.emon.hadoop.FileSystemEE</value>
  </property>

  <!-- Enable the Alluxio Edge Cache Integration for s3a URIs -->
  <property>
    <name>fs.s3a.impl</name>
    <value>alluxio.emon.hadoop.FileSystemEE</value>
  </property>

  <!-- Enable the Alluxio Edge Cache Integration for hdfs URIs -->
  <!--
  <property>
    <name>fs.hdfs.impl</name>
    <value>alluxio.emon.hadoop.FileSystemEE</value>
  </property>
  -->

</configuration>
EOF
```

If you want Alluxio to also service requests for LOCATION setting of hdfs://, then you can un-comment the section in the core-site.xml file, like this:

    <property>
        <name>fs.hdfs.impl</name>
        <value>alluxio.emon.hadoop.FileSystemEE</value>
    </property>

But you must also install the appropriate Alluxio Edge understore jar file for the Hadoop release you are using. These jar files are contained in the original Alluxio Edge install tar file you received. There names will be similar to these:

     alluxio-underfs-emon-hadoop-2.7-304-SNAPSHOT.jar
     alluxio-underfs-emon-hadoop-2.10-304-SNAPSHOT.jar
     alluxio-underfs-emon-hadoop-3.3-304-SNAPSHOT.jar

#### c. Create the Alluxio metrics configuration file

Alluxio Edge can generate metrics using a the Java management extensions (JMX). By doing this, the metrics can be integrated with Prometheus based monitoring systems such as Grafana. Create a metrics.properties file to enable Alluxio Edge to generate JMX metrics using the commands:

```
cat <<EOF > config-files/alluxio/metrics.properties
#
# FILE:    metrics.properties
#
# DESC:    This properties file enables the Alluxio Jmx sink
#          It should be placed in: /home/trino/alluxio/conf/metrics.properties

sink.jmx.class=alluxio.metrics.sink.JmxSink

EOF
```

#### d. Create a Trino "minio" catalog configuration

Since we are using MinIO as our persistent object store, configure a Trino catalog to point to Minio using the commands:

```
cat <<EOF > config-files/trino/catalog/hive.properties
#
# FILE: hive.properties
#
# DESC: This is the Trino catalog config file for the MinIO S3 store. 
#       It should be placed in: /etc/trino/catalog/hive.properties
# 
connector.name=hive
hive.s3-file-system-type=HADOOP_DEFAULT
hive.metastore.uri=thrift://hive-metastore:9083
hive.s3.endpoint=http://minio:9000
hive.s3.aws-access-key=minio
hive.s3.aws-secret-key=minio123
hive.non-managed-table-writes-enabled=true
hive.s3select-pushdown.enabled=true
hive.storage-format=ORC
hive.allow-drop-table=true
hive.config.resources=/home/trino/alluxio/conf/core-site.xml
EOF
```
#### e. Create the jmx_export_config.yaml file

To enable JMX and Prometheus integration, a JVM export configuration file must be created and referenced in the jvm.config file (see sub-step f below). Create the file using the commands:

```
cat <<EOF > config-files/trino/jmx_export_config.yaml
#
# FILE: jmx_export_config.yaml
#
# DESC: This is the Alluxio Edge Java JMX metrics export file. It should
#       be placed in: /etc/trino/jmx_export_config.yaml
#
---
startDelaySeconds: 0
ssl: false
global:
  scrape_interval:     15s
  evaluation_interval: 15s
rules:
- pattern: ".*"
EOF
```

#### f. Create the Trino JVM configuration file

The jvm.config file defines the Java virtual machine configuration for the Trino coordinator and worker nodes. In this config file, several settings need to be added to integrate Trino with Alluxio Edge, including the -Dalluxio.home and -Dalluxio.conf.dir environment variables and the -Dalluxio.metrics.conf.file environment variable. Also, for JMX and Prometheus integration, the -javaagent argument must be set and point to the JMX Prometheus agent jar file. In this git repo, the jmx_prometheus_javaagent-0.20.0.jar is provided for your use. In a production deployment, you would have to stage that agent jar file yourself. Create the jvm.config file with these commands:

```
cat <<EOF > config-files/trino/jvm.config
#
# FILE: jvm.config
#
# DESC: This is the Trino Java JVM configuration script and should be
#       placed in: /etc/trino/jvm.config
#

-server
#-Xms32G
#-Xmx32G
-Xms6G
-Xmx6G
-XX:InitialRAMPercentage=80
-XX:MaxRAMPercentage=80
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExitOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-XX:ReservedCodeCacheSize=256M
-XX:PerMethodRecompilationCutoff=10000
-XX:PerBytecodeRecompilationCutoff=10000
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000

# Improve AES performance for S3, etc. on ARM64 (JDK-8271567)
-XX:+UnlockDiagnosticVMOptions
-XX:+UseAESCTRIntrinsics

# Setup Alluxio Edge integration
-Dalluxio.home=/home/trino/alluxio
-Dalluxio.conf.dir=/home/trino/alluxio/conf

# Setup Alluxio Edge cache metrics
-Dalluxio.metrics.conf.file=/home/trino/alluxio/conf/metrics.properties
-javaagent:/home/trino/alluxio/lib/jmx_prometheus_javaagent-0.20.0.jar=9696:/etc/trino/jmx_export_config.yaml

# end of file
EOF
```

### Step 5. Build a custom Trino with Alluxio docker image

Alluxio Edge for Trino is designed to tightly integrate with the Trino coordinator and worker processes, and the Trino catalogs for Hive, Hudi, Delta-Lake and Iceberg. In this step you will build a Docker image containing the Trino release files and the Alluxio Edge release files as well as the modified configuration scripts.

#### a. Create the Dockerfile spec file

To build a new Docker image file, the Docker build utility requires a specification file named "Dockerfile".  Create this file and include the steps needed to copy the Alluxio Edge jar files and configuration files into the Docker image. For this deployment, create the Dockerfile with these commands:

```
cat <<EOF > Dockerfile

# FILE: Dockerfile
#
# UASGE: docker build -t mytrino/trino-alluxio-edge .
#
# NOTE: Remove the escape chars (\${...}) if manually copying and pasting
#       (that is, not using the "cat <<EOF > Dockerfile" command)

ARG TRINO_VERSION=403
#ARG TRINO_VERSION=418

FROM docker.io/trinodb/trino:\${TRINO_VERSION}

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
COPY jars/alluxio-emon-\${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/hive
COPY jars/alluxio-emon-\${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/hudi
COPY jars/alluxio-emon-\${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/delta-lake  
COPY jars/alluxio-emon-\${ALLUXIO_VERSION}-client.jar /usr/lib/trino/plugin/iceberg

# Copy the Alluxio Edge under store jar file to the Trino lib dir 
COPY jars/alluxio-underfs-emon-s3a-\${ALLUXIO_VERSION}.jar          /home/trino/alluxio/lib
#COPY jars/alluxio-underfs-emon-hadoop-3.3-\${ALLUXIO_VERSION}.jar  /home/trino/alluxio/lib
#COPY jars/alluxio-underfs-emon-hadoop-2.10-\${ALLUXIO_VERSION}.jar /home/trino/alluxio/lib
#COPY jars/alluxio-underfs-emon-hadoop-2.7-\${ALLUXIO_VERSION}.jar  /home/trino/alluxio/lib

# Copy the JVX Prometheus agent jar file to the Alluxio lib dir
COPY jars/jmx_prometheus_javaagent-\${JMX_PROMETHEUS_AGENT_VERSION}.jar /home/trino/alluxio/lib

# Copy the Trino config files to the Trino etc dir
COPY config-files/trino/catalog/hive.properties /etc/trino/catalog
COPY config-files/trino/jvm.config               /etc/trino
COPY config-files/alluxio/core-site.xml          /etc/trino
COPY config-files/trino/jmx_export_config.yaml   /etc/trino

USER trino

# Start the Trino service
CMD ["/usr/lib/trino/bin/run-trino"]

EOF
```

#### b. Build the Docker image

Build the Docker image using the "docker build" command:

     docker build -t mytrino/trino-alluxio-edge .

#### c. (Optional) Upload image to a Docker image registry

If you intend to deploy Trino with Alluxio Edge on a Kubernetes cluster, then you will have to upload the Docker image to a repository that can respond to a "docker pull" request. Usually the repository is hosted inside of your network firewall with products such as Artifactory, JFrog or a self hosted Docker registry.

If you are using DockerHub as your docker registry, Use the "docker push" command to upload the image, like this:

     docker login --username=<PUT_YOUR_DOCKER_HUB_USER_ID_HERE>

     docker tag <PUT_YOUR_NEW_IMAGE_ID_HERE> <PUT_YOUR_DOCKER_HUB_USER_ID_HERE>/trino-alluxio-edge:latest

     docker push <PUT_YOUR_DOCKER_HUB_USER_ID_HERE>/trino-alluxio-edge:latest

     docker pull <PUT_YOUR_DOCKER_HUB_USER_ID_HERE>/trino-alluxio-edge:latest

### Step 6. Launch the docker containers with Docker Compose

In this deployment, we will be using the Docker Compose utility to launch the Trino with Alluxio Docker images. If you intend to launch the Trino with Alluxio Docker image on a Kubernetes cluster, then you would follow the instructions provided by your Trino release.

a. Remove any previous docker volumes that may have been used by the containers, using the command:

     docker volume prune

Launch the containers defined in the docker-compose.yml file using the command:

     docker-compose up -d

or, on Linux:

     docker compose up -d

The command will create the network object and the docker volumes, then it will take some time to pull the various docker images. When it is complete, you see this output:

     $ docker-compose up -d
     Creating network "alluxio-trino-edge-cache_custom" with driver "bridge"
     Creating volume "alluxio-trino-edge-cache_mariadb-data" with local driver
     Creating volume "alluxio-trino-edge-cache_minio-data" with local driver
     Creating volume "alluxio-trino-edge-cache_trino-coordinator-data" with local driver
     Creating volume "alluxio-trino-edge-cache_trino-worker1-data" with local driver
     Creating volume "alluxio-trino-edge-cache_prometheus_data" with local driver
     Creating trino-coordinator ... done
     Creating trino-worker1     ... done
     Creating prometheus           ... done
     Creating minio             ... done
     Creating mariadb              ... done
     Creating grafana           ... done
     Creating minio-create-buckets ... done
     Creating hive-metastore       ... done

If you experience errors for not enough CPU, Memory or disk resources, use your Docker console to increase the resource allocations. You may need up to 4 CPUs, 8 GB of Memory and 200 GB of disk image space in your Docker resource settings.

### Step 7. Open two shell sessions 

Open two shell sessions - one into the trino-coordinator Docker container and one into the trino-worker1 Docker container. Run the following command to launch a shell session in the trino-coordinator container:

     docker exec -it trino-coordinator bash

Run the following command to launch a shell session in the trino-worker1 container:

     docker exec -it trino-worker1 bash

Your shell session windows should look like this:

![alt Alluxio Edge Solution](images/Alluxio_Edge_Shell_Sessions.png?raw=true)

### Step 8. Run Trino queries and observe the Alluxio Edge cache

a. In the trino-coordinator shell session window, start a Trino command line session:

     trino --catalog minio --debug

The TPC/H Trino catalog has been pre-configured for this Trino instance and there is a table named "tpch.sf100.customer" that contains about 15 million rows. We will use that table to create a new table in the local MinIO storage environment. Run the following Trino CREATE TABLE command:

      -- Create a 15M row table in MinIO storage
      USE default;

      CREATE TABLE default.customer
      WITH (
        format = 'ORC',
        external_location = 's3a://minio-bucket-1/user/hive/warehouse/customer/'
      ) 
      AS SELECT * FROM tpch.sf100.customer;

b. In the trino-worker1 shell session window, check that Alluxio Edge has not cached any files in the cache storage area yet:

     find /dev/shm/alluxio_cache/

It will show an empty directory:

     $ find /dev/shm/alluxio_cache/
     /dev/shm/alluxio_cache/
     /dev/shm/alluxio_cache/LOCAL

c. Back on the trino-coordinator shell session, run a Trino query to cause Alluxio Edge to cache some files:

     SELECT count(*) AS No_Of_ACCTS FROM default.customer
     WHERE acctbal > 1000.00 AND acctbal < 7500.00;

Then, on the trino-worker1 shell session, check the number of cache objects Alluxio Edge created. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It will show about 118 cache files were created from the first Trino query:

     $ find /dev/shm/alluxio_cache/ | wc -l
     118

d. Then, in the trino-coordinator shell session window, run a second Trino query that queries more data:

     SELECT name, mktsegment, acctbal FROM default.customer
     WHERE  acctbal > 3500.00 AND acctbal < 4000.00 
     ORDER  BY acctbal;

e. In the trino-worker1 shell session window, recheck the number of Alluxio Edge cache files and you should see an increasing number of cache files. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It will show more cache files being created by Alluxio Edge:

     $ find /dev/shm/alluxio_cache/ | wc -l
     154

f. Back in the trino-coordinator shell session window, run a third Trino query:

     SELECT mktsegment, AVG(acctbal) FROM default.customer
     WHERE  acctbal > 3500.00 AND acctbal < 4000.00 
     GROUP  BY mktsegment, acctbal;

g. Again, in the trino-worker1 shell session window, recheck the number of Alluxio Edge cache files and you should see that the number of cache files did not change. The third query, while different from the other two queries, was able to get all of its data from the Alluxio Edge cache and did not have to go to the S3 under store (MinIO) to get the data. And it did not have to cache any more data either. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It shows the same amount of cache files:

     $ find /dev/shm/alluxio_cache/ | wc -l
     154

h. If you change the query's projection list and add more columns, you will see more data being cached. In the trino-coordinator shell session window, run this Trino query:

     SELECT custkey, name, mktsegment, phone, acctbal, comment 
     FROM  default.customer
     WHERE acctbal > 3500.00 AND acctbal < 4000.00 
     ORDER BY name;

i. Now, if you recheck the number of cache files in the trino-worker1 shell session window, you will see a much larger number of cache files. This was caused by a great number of columns being read from the parquet files and by Alluxio Edge caching that data. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It will show a large increase in the number of cache files being created by Alluxio Edge:

     $ find /dev/shm/alluxio_cache/ | wc -l
     480

### Step 9. Explore the integration between Trino and Alluxio Edge

Alluxio Edge is integrated with Trino by:

- Copying the Alluxio Edge jar files to the Trino Java class path.
- Configuring Trino to use Alluxio Edge when accessing the persistent store (MinIO in this case).
- Configuring the Trino Catalog to use Alluxio Edge.
- Configuring Alluxio Edge to point to cache storage (NVMe in this case).

a. Copying the Alluxio Edge jar files to the Trino Java class path

Explore how the Alluxio Edge jar files are installed in the Trino class path. Open a shell session to the Trino Coordinator docker container like this:

     docker exec -it trino-coordinator bash

Some Trino distributions contain older version of Alluxio client jar files and those old files should be removed with a command like this:

     find /usr/lib/trino -name alluxio*shaded* -exec rm {} \;

Once those older jar files are removed, the Alluxio Edge jar files are copied to the Trino plugin directories for Hive, Hudi, Delta Lake and Iceberg. See the files with this command:

     find /usr/lib/trino | grep alluxio

The results will show two Alluxio jar files (alluxio-emon-client.jar and alluxio-underfs-emon-s3a.jar) in each of the plugin directories:

     $ find /usr/lib/trino | grep alluxio
     /usr/lib/trino/plugin/hive/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar
     /usr/lib/trino/plugin/hive/alluxio-emon-304-SNAPSHOT-client.jar
     /usr/lib/trino/plugin/hudi/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar
     /usr/lib/trino/plugin/hudi/alluxio-emon-304-SNAPSHOT-client.jar
     /usr/lib/trino/plugin/delta-lake/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar
     /usr/lib/trino/plugin/delta-lake/alluxio-emon-304-SNAPSHOT-client.jar
     /usr/lib/trino/plugin/iceberg/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar
     /usr/lib/trino/plugin/iceberg/alluxio-emon-304-SNAPSHOT-client.jar

b. Configuring Trino to use Alluxio Edge when accessing the persistent store 

Explore how Trino references Alluxio Edge when queries need to access the persistent store (MinIO in this case). The first thing to do is enable the Alluxio Edge Java class to be used when queries reference a Hive table with a LOCATION setting of s3:// or s3a://. This is done in the Trino core-site.xml file and can be viewed with the following command:

     cat /etc/trino/core-site.xml

The core-site.xml file shows that an Alluxio Edge class named alluxio.emon.hadoop.FileSystemEE is being implemented for the s3 and s3a file system classes:

     $ cat /etc/trino/core-site.xml
     <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
     <configuration>
     
        <!-- Enable the Alluxio Edge Cache Integration for s3 URIs -->
        <property>
          <name>fs.s3.impl</name>
          <value>alluxio.emon.hadoop.FileSystemEE</value>
        </property>
     
        <!-- Enable the Alluxio Edge Cache Integration for s3a URIs -->
        <property>
          <name>fs.s3a.impl</name>
          <value>alluxio.emon.hadoop.FileSystemEE</value>
        </property>
     
        <!-- Enable the Alluxio Edge Cache Integration for hdfs URIs -->
        <!--
        <property>
          <name>fs.hdfs.impl</name>
          <value>alluxio.emon.hadoop.FileSystemEE</value>
        </property>
        -->
     
     </configuration>

If you want Alluxio to also service requests for LOCATION setting of hdfs://, then you can un-comment the section in the core-site.xml file, like this:

    <property>
        <name>fs.hdfs.impl</name>
        <value>alluxio.emon.hadoop.FileSystemEE</value>
    </property>

But you must also install the appropriate Alluxio Edge understore jar file for the Hadoop release you are using. These jar files are contained in the original Alluxio Edge install tar file you received. There names will be similar to these:

     alluxio-underfs-emon-hadoop-2.7-304-SNAPSHOT.jar
     alluxio-underfs-emon-hadoop-2.10-304-SNAPSHOT.jar
     alluxio-underfs-emon-hadoop-3.3-304-SNAPSHOT.jar

If you have a separate Alluxio Enterprise Edition cluster that you would like to access via Trino queries using the LOCATION setting of alluxio://, then you can add a new section to the core-site.xml file like this:

     <property>
        <name>fs.alluxio.impl</name>
        <value>alluxio.emon.hadoop.FileSystemEE</value>
     </property>

There is no need to copy a new understore jar file.

There is also a requirement to modify the Trino /etc/trino/jvm.conf file to include a the Alluxio Edge variable definitions that point to the Alluxio Edge home directory and the conf directory, like this:

     # Setup Alluxio edge cache integration
     -Dalluxio.home=/home/trino/alluxio
     -Dalluxio.conf.dir=/home/trino/alluxio/conf

c. Configuring Trino Catalog integration to use Alluxio Edge

The Trino hive catalog must be modified to point to the cores-site.xml file created above in step 2.b. In the Trino catalog's hive.properties file, you can reference the core-site.xml file containing the Alluxio Edge configuration settings. In this case, the Trino catalog configuration file is located at:

     /etc/trino/catalog/hive.properties

And the line that is added to point to the Alluxio Edge configured core-site.xml file is:

     hive.config.resources=/etc/trino/core-site.xml

d. Configuring Alluxio Edge to point to cache storage (NVMe in this case).

The Alluxio home directory can be put anywhere on the Trino node. On this demo environment, a directory named:

     /home/trino/alluxio/

was created to store the Alluxio Edge jar files and the Alluxio Edge configuration files. The main Alluxio configuration file is named alluxio-site.properties and this is where the settings are placed to direct Alluxio Edge to integrate with under store (MinIO in this case) and to direct Alluxio Edge to use local NVMe storage for caching data. Run the following command to see the contents of the alluxio-site.properties file:

     cat /home/trino/alluxio/conf/alluxio-site.properties

The contents are displayed and you can see the alluxio.underfs.s3.endpoint property is set to the MinIO endpoint and the cache medium is specified with the alluxio.user.client.cache.* properties. In this demo environment, we are using the RAM disk for cache, but in a production environment, larger NVMe storage volumes would be used.

     # FILE: alluxio-site.properties
     #

     # Alluxio under file system setup (MinIO)
     #
     alluxio.underfs.s3.endpoint=http://minio:9000
     s3a.accessKeyId=minio
     s3a.secretKey=minio123
     alluxio.underfs.s3.inherit.acl=false
     alluxio.underfs.s3.disable.dns.buckets=true

     # Alluxio under file system setup (AWS S3)
     #
     #s3a.accessKeyId=<PUT_YOUR_AWS_ACCESS_KEY_ID_HERE>
     #s3a.secretKey=<PUT_YOUR_AWS_SECRET_KEY_HERE>
     #alluxio.underfs.s3.region=<PUT_YOUR_AWS_REGION_HERE> # Example: us-east-1

     # Alluxio under file system setup (HDFS)
     #
     #alluxio.underfs.hdfs.configuration=<PUT_YOUR_CORE_SITE_AND_HDFS_SITE_FILES_HERE> # example /home/trino/alluxio/conf/core-site.xml:/home/trino/alluxio/conf/hdfs-site.xml
     #alluxio.underfs.hdfs.remote=true

     # Enable edge cache on client (RAM disk only)
     #
     alluxio.user.client.cache.enabled=true
     alluxio.user.client.cache.size=1GB
     alluxio.user.client.cache.dirs=/dev/shm/alluxio_cache

     # Enable edge cache on client (with 2 NVMe volumes)
     #
     #alluxio.user.client.cache.enabled=true
     #alluxio.user.client.cache.size=1024GB,3096GB
     #alluxio.user.client.cache.dirs=/mnt/nvme0/alluxio_cache,/mnt/nvme1/alluxio_cache

     # Enable edge metrics collection
     alluxio.user.metrics.collection.enabled=true

     # Disable DORA
     alluxio.dora.enabled=false

     # end of file

### Step 10. Explore the Alluxio Edge Dashboard

a. Display the Prometheus Web console

Point your Web browser to the Prometheus docker container at:

     http://localhost:9090

b. Disoplay the Grafana Web console

Point your Web browser to the Grafana docker container at:

     http://localhost:3000

When prompted, sign in with the user "admin" and the password "admin". When you see a message asking you to change the password, you can click on the "Skip" link to keep the same password.

In the upper left side of the dashboard, click on the drop down menu (just to the left of the "Home" label).

![alt Grafana Home Menu](images/Alluxio_Edge_Grafana_Home_Menu.png?raw=true)

Then click on the "Dashboards" link to display the folders and dashboards and then click on the "Trino_Alluxio" folder link to view the "Alluxio Edge Dashboard" dashboard. Click on the link for that dashboard to view the panels.

At the top of the Grafana dashboard, you see the "Alluxio Edge - Cache Hit Rate" panel, which should look like the screen shot below. The Alluxio Edge Grafana metrics tell the story of what is happening with the Alluxio Edge data cache system when various Trino query jobs are executed.

At first Alluxio Edge had no data in the cache and no cache hits or misses. Then, the first Trino query was run at 11:51:00 and that query experienced a zero cache hit rate (not surprisingly), but caused approximately 80 MB of data to be read from the MinIO under store into the Alluxio Edge cache, as shown in the "Data Read from UFS" panel and the "Cache Space Used" panel. Here is a copy of the first query statement:

```
SELECT count(*) AS No_Of_ACCTS FROM default.customer
WHERE acctbal > 1000.00 AND acctbal < 7500.00;
```

At 11:53:30, the second Trino query was run. Because it accessed most of the same data that the first query retrieved, it saw a cache hit rate of approximately 75% as shown in the "Cache Hit Rate" panel and the "Data Read from Cache" panel. However, because some of the query results were not already in the cache, Alluxio Edge also read some data from the MinIO under store as shown in the "Data Read from UFS" panel and the "Cache Space Used" panel. 

Here is a copy of the second query statement:

```
SELECT name, mktsegment, acctbal FROM default.customer
WHERE  acctbal > 3500.00 AND acctbal < 4000.00 
ORDER  BY acctbal;
```

At 11:55:00, the third Trino query was run. While the query statement was different from the previous queries, the data it needed was fully resident in the Alluxio Edge cache and it experienced a 100% cache hit rate, as shown in the "Cache Hit Rate" panel. Also, it did not cause Alluxio Edge to read any data from the MinIO under store or increase the amount of data in the cache as shown in the "Data Read from UFS" panel and the "Cache Space Used" panel.

Here is a copy of the third query statement:

```
SELECT mktsegment, AVG(acctbal) FROM default.customer
WHERE  acctbal > 3500.00 AND acctbal < 4000.00 
GROUP  BY mktsegment, acctbal;
```

At 11:56:30, the fourth Trino query was run. This query was very different from the previous queries and it required a lot of new data that was not in the Alluxio Edge cache which resulted in decreasing cache hit rates that bottomed out at under 20% as shown in the "Cache Hit Rate" panel. Of course, it also caused Alluxio to read much more data from the MinIO under store and cache that new data as shown in the "Data Read from UFS" panel and the "Cache Space Used" panel.  If the Alluxio Edge cache was full at the time this query was run, Alluxio Edge would have had to evict some older data to accommodate this new data, but there was enough room for this new data to be added to the cache.

Here is a copy of the fourth query statement:
```
SELECT custkey, name, mktsegment, phone, acctbal, comment 
FROM  default.customer
WHERE acctbal > 3500.00 AND acctbal < 4000.00 
ORDER BY name;
```

This is a simple example with Trino queries being run one at a time. In a real production environment, there could be hundreds of Trino jobs running concurrently and Alluxio Edge would handle all their data retrieval requests in a highly parallelized fashion with cache hits, misses, and evictions happening all at once.

![alt Alluxio Edge Grafana Cache Hit Rate](images/Alluxio_Edge_Grafana_Cache_Hit_Rate.png?raw=true)

### Step 11. Explore the Alluxio Edge Dashboard configuration

TBD

--

Please Direct questions or comments to greg.palmer@alluxio.com
