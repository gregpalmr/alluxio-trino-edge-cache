# alluxio-trino-edge-cache

### A demonstration of Alluxio Edge caching data for Trino queries.

## INTRODUCTION

In the past, data analytics platforms were deployed with the compute resources being tightly coupled to the storage resources (think Hadoop, Vertica, SaS, Teradata, etc.). This provided very fast data access with data locality used to retrieve data without having to make network calls to storage layers. Today, however, data analytics platforms are deployed in hybrid cloud and multi-cloud environments where the data is not stored near the compute resources and that separation of compute and storage loses the concept of data locality and often results in slow query performance, increased charges for cloud storage API costs and cloud storage egress costs.

Instead of replicating whole data sets, which can be costly and error prone, Alluxio Edge allows data analytics platforms to run where it makes sense and still be able to access data storage environments in a fast, efficient, and less costly manner. Alluxio Edge deploys a tightly integrated local cache system on Trino and PrestoDB nodes which helps improve performance of queries, reduce cloud storage API and egress costs and eliminates the need to copy data or replicate data for
every compute environment.

![alt Alluxio Edge Solution](images/Alluxio_Edge_Solution_Diag.png?raw=true)

With Alluxio Edge, you can improve query performance, speed up I/O, reduce cloud storage API calls, and reduce network congestion and reduce the load on your object storage environments.

Alluxio Edge works by embedding itself in the Trino or PrestoBD worker node process itself and monitors the file requests in real time. If a file is already cached on the local cache storage (typically NVMe), Alluxio returns the file without having to retrieve it again from the persistent object store.  If the file is not already cached, Alluxio Edge retrieves it from the persistent object store and caches it locally as well.

![alt Alluxio Edge Solution](images/images/Alluxio_Edge_How_Does_It_Work.png?raw=true)

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

b. There are two Alluxio Edge Java jar files that need to be installed on each Trino or PrestoDB node. Extract the jar files from the tar file using the commands:

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
     Creating volume "alluxio-trino-edge-cache_prometheus_data" with local driver
     Creating prometheus           ... done
     Creating minio             ... done
     Creating mariadb              ... done
     Creating grafana           ... done
     Creating trino-coordinator ... done
     Creating minio-create-buckets ... done
     Creating hive-metastore       ... done

If you experience errors for not enough CPU, Memory or disk resources, use your Docker console to increase the resource allocations. You may need up to 4 CPUs, 8 GB of Memory and 200 GB of disk image space in your Docker resource settings.

### Step 5. Open two shell session into the Trino docker container

Open two shell sessions into the trino-coordinator docker container. The trino-coordinator container deploys the Trino coordinator and Trino worker processes in one container. Run the following commands in two different shell windows:

     docker exec -it trino-coordinator bash

     docker exec -it trino-coordinator bash

Your shell session windows should look like this:

![alt Alluxio Edge Solution](images/Alluxio_Edge_Shell_Sessions.png?raw=true)

### Step 6. Run Trino queries and observe the Alluxio Edge cache

a. In the first shell session window, start a Trino command line session:

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

b. In the second shell session window, check that Alluxio Edge has not cached any files in the cache storage area yet:

     find /dev/shm/alluxio_cache/

It will show an empty directory:

     $ find /dev/shm/alluxio_cache/
     /dev/shm/alluxio_cache/
     /dev/shm/alluxio_cache/LOCAL

c. Back on the first shell session, run a Trino query to cause Alluxio Edge to cache some files:

     trino>

          SELECT count(*) AS No_Of_ACCTS FROM default.customer
          WHERE acctbal > 1000.00 AND acctbal < 7500.00;

Then, on the second shell session, check the number of cache objects Alluxio Edge created. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It will show about 118 cache files were created from the first Trino query:

     $ find /dev/shm/alluxio_cache/ | wc -l
     118

d. Then, in the first shell session window, run a second Trino query that queries more data:

     trino>

          SELECT name, mktsegment, acctbal FROM default.customer
          WHERE  acctbal > 3500.00 AND acctbal < 4000.00 
          ORDER  BY acctbal;

e. In the second shell session window, recheck the number of Alluxio Edge cache files and you should see an increasing number of cache files. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It will show more cache files being created by Alluxio Edge:

     $ find /dev/shm/alluxio_cache/ | wc -l
     154

f. Back in the first shell session window, run a third Trino query:

     trino>

          SELECT mktsegment, AVG(acctbal) FROM default.customer
          WHERE  acctbal > 3500.00 AND acctbal < 4000.00 
          GROUP  BY mktsegment, acctbal;

g. Again, in the second shell session window, recheck the number of Alluxio Edge cache files and you should see that the number of cache files did not change. The third query, while different from the other two queries, was able to get all of its data from the Alluxio Edge cache and did not have to go to the S3 under store (MinIO) to get the data. And it did not have to cache any more data either. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It shows the same amount of cache files:

     $ find /dev/shm/alluxio_cache/ | wc -l
     154

h. If you change the query's projection list and add more columns, you will see more data being cached. In the first shell session window, run this Trino query:

     trino>

          SELECT custkey, name, mktsegment, phone, acctbal, comment 
          FROM  default.customer
          WHERE acctbal > 3500.00 AND acctbal < 4000.00 
          ORDER BY name;

i. Now, if you recheck the number of cache files in the second shell session window, you will see a much larger number of cache files. This was caused by a great number of columns being read from the parquet files and by Alluxio Edge caching that data. Run the command:

     find /dev/shm/alluxio_cache/ | wc -l

It will show a large increase in the number of cache files being created by Alluxio Edge:

     $ find /dev/shm/alluxio_cache/ | wc -l
     480

### Step 7. Explore the integration between Trino and Alluxio Edge


