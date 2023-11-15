# alluxio-trino-edge-cache

### A demonstration of Alluxio Edge caching data for Trino queries.

## INTRODUCTION

In the past, data analytics platforms were deployed with the compute resources being tightly coupled to the storage resources (think Hadoop, Vertica, SaS, Teradata, etc.). This provided very fast data access with data locality used to retrieve data without having to make network calls to storage layers. Today, however, data analytics platforms are deployed in hybrid cloud and multi-cloud environments where the data is not stored near the compute resources and that separation of compute and storage loses the concept of data locality and often results in slow query performance, increased charges for cloud storage API costs and cloud storage egress costs.

Instead of replicating whole data sets, which can be costly and error prone, Alluxio Edge allows data analytics platforms to run where it makes sense and still be able to access data storage environments in a fast, efficient, and less costly manner. Alluxio Edge deploys a tightly integrated local cache system on Trino and PrestoDB nodes which helps improve performance of queries, reduce cloud storage API and egress costs and eliminates the need to copy data or replicate data for
every compute environment.

![alt Alluxio Edge Solution](images/Alluxio_Edge_Solution_Diag.png?raw=true)

With Alluxio Edge, you can improve query performance, speed up I/O, reduce cloud storage API calls, and reduce network congestion and reduce the load on your object storage environments.

Alluxio Edge works by embedding itself in the Trino or PrestoBD worker node process itself and monitors the file requests in real time. If a file is already cached on the local cache storage (typically NVMe), Alluxio returns the file without having to retrieve it again from the persistent object store.  If the file is not already cached, Alluxio Edge retrieves it from the persistent object store and caches it locally as well.

![alt Alluxio Edge Solution](images/Alluxio_Edge_How_Does_It_Work.png?raw=true)

This git repo provides a working environment where Alluxio Edge is integrated with Trino and Apache Hive and provides examples of how Alluxio Edge caches data being queried.

## USAGE

### Step 1. Install Docker desktop 

Install Docker desktop on your laptop, including the docker-compose command.

     See: https://www.docker.com/products/docker-desktop/

### Step 2. Clone this repo

Use the git command to clone this repo (or download the zip file from the github.com site).

     git clone https://github.com/gregpalmr/alluxio-trino-edge-cache

     cd alluxio-trino-edge-cache

### Step 3. Download the Alluxio Edge jar files

a. Contact your Alluxio account representative at sales@alluxio.com and request a trial version of Alluxio Edge. Follow their instructions for downloading the installation tar file.

b. There are two Alluxio Edge Java jar files that need to be installed on each Trino node. Extract the jar files from the tar file using the commands:

     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar.gz \
     alluxio-enterprise-304-SNAPSHOT/client/alluxio-emon-304-SNAPSHOT-client.jar

     tar xf ~/Downloads/alluxio-enterprise-304-SNAPSHOT-bin-4d128112c2.tar.gz \
     alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar

c. Copy the extracted jar files to the "jars" directory:

     cp alluxio-enterprise-304-SNAPSHOT/client/alluxio-emon-304-SNAPSHOT-client.jar ./jars/

     cp alluxio-enterprise-304-SNAPSHOT/lib/alluxio-underfs-emon-s3a-304-SNAPSHOT.jar ./jars/

d. Remove the unused portion of the release directory:

     rm -rf alluxio-enterprise-304-SNAPSHOT

### Step 4. Launch the docker containers

Remove any previous docker volumes that may have been used by the containers, using the command:

     docker volume prune

Launch the containers defined in the docker-compose.yml file using the command:

     docker-compose up -d

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

### Step 5. Open two shell sessions 

Open two shell sessions - one into the trino-coordinator Docker container and one into the trino-worker1 Docker container. Run the following command to launch a shell session in the trino-coordinator container:

     docker exec -it trino-coordinator bash

Run the following command to launch a shell session in the trino-worker1 container:

     docker exec -it trino-worker1 bash

Your shell session windows should look like this:

![alt Alluxio Edge Solution](images/Alluxio_Edge_Shell_Sessions.png?raw=true)

### Step 6. Run Trino queries and observe the Alluxio Edge cache

a. In the trino-coordinator shell session window, start a Trino command line session:

     trino --catalog minio --debug

The TPC/H Trino catalog has been pre-configured for this Trino instance and there is a table named "tpch.sf100.customer" that contains about 15 million rows. We will use that table to create a new table in the local MinIO storage environment. Run the following Trino CREATE TABLE command:

      -- Create a 15M row table in MinIO storage
      USE default;

      CREATE TABLE default.customer
      WITH (
        format = 'ORC',
        external_location = 's3a://hive/warehouse/customer/'
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

### Step 7. Explore the integration between Trino and Alluxio Edge

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

The core-site.xml file shows that an Alluxio Edge class named alluxio.emon.hadoop.FileSystemEE is being implemented for the s3 and s3a filesystem classes:

     $ cat /etc/trino/core-site.xml
     <?xml version="1.0"?>
     <configuration>
     
         <!-- Enable the Alluxio Edge Cache Integration -->
         <property>
           <name>fs.s3a.impl</name>
           <value>alluxio.emon.hadoop.FileSystemEE</value>
         </property>
     
         <property>
           <name>fs.s3.impl</name>
           <value>alluxio.emon.hadoop.FileSystemEE</value>
         </property>
     
     </configuration>

If you want Alluxio to also service requests for LOCATION setting of hdfs://, then you can add a new section in the core-site.xml file, like this:

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

     /etc/trino/catalog/minio.properties

And the line that is added to point to the Alluxio Edge configured core-site.xml file is:

     hive.config.resources=/etc/trino/core-site.xml

d. Configuring Alluxio Edge to point to cache storage (NVMe in this case).

The Alluxio home directory can be put anywhere on the Trino node. On this demo environment, a directory named:

     /home/trino/alluxio/

was created to store the Alluxio Edge jar files and the Alluxio Edge configuration files. The main Alluxio configuration file is named alluxio-site.properties and this is where the settings are placed to direct Alluxio Edge to integrate with under store (MinIO in this case) and to direct Alluxio Edge to use local NVMe storage for caching data. Run the following command to see the contents of the alluxio-site.properties file:

     cat /home/trino/alluxio/conf/alluxio-site.properties

The contents are displayed and you can see the alluxio.underfs.s3.endpoint property is set to the MinIO endpoint and the cache medium is specified with the alluxio.user.client.cache.* properties. In this demo environment, we are using the RAM disk for cache, but in a production environment, larger NVMe storage volumes would be used.

     $ cat /home/trino/alluxio/conf/alluxio-site.properties
     # FILE: alluxio-site.properties
     #
     
     # Disable DORA
     #
     alluxio.dora.enabled=false
     
     # Alluxio under file system setup (MinIO)
     #
     alluxio.underfs.s3.endpoint=http://minio:9000
     s3a.accessKeyId=minio
     s3a.secretKey=minio123
     alluxio.underfs.s3.inherit.acl=false
     alluxio.underfs.s3.disable.dns.buckets=true
     
     # Enable edge cache on client
     #
     alluxio.user.client.cache.enabled=true
     alluxio.user.client.cache.size=1GB
     alluxio.user.client.cache.dirs=/dev/shm/alluxio_cache
     
     # Enable edge metrics collection
     alluxio.user.metrics.collection.enabled=true
     
     # end of file


### Step 8. Explore the Alluxio Edge Dashboard

a. Display the Prometheus Web console

Point your Web browser to the Prometheus docker container at:

     http://localhost:9090

b. Disoplay the Grafana Web console

Point your Web browser to the Grafana docker container at:

     http://localhost:3000

When prompted, sign in with the user "admin" and the password "admin". When you see a message asking you to change the password, you can click on the "Skip" link to keep the same password.

In the upper left side of the dashboard, click on the drop down menu (just to the left of the "Home" label).

![alt Grafana Home Menu](images/Alluxio_Edge_Grafana_Home_Menu.png?raw=true)

Then click on the "Dashboards" link to display the folders and dashboards. Then click on the "Trino-Alluxio" folder link to view the Trino-Alluxio-Edge-Cache-Monitor dashboard. Click on the link for that dashboard to view the panels.

![alt Grafana Home Menu](images/Alluxio-Edge-Grafana-Dashboard1.png?raw=true)

In the Grafana dashboard, scroll down until you see the "Alluxio Cache Hit Rate" panel, which should look like this:

![alt Alluxio Edge Grafana Cache Hit Rate](images/alluxio-edge-grafana-cache-hit-rate.png?raw=true)

### Step 9. Explore the Alluxio Edge Dashboard configuration

TBD

--

Please Direct questions or comments to greg.palmer@alluxio.com
