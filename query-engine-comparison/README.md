Query Engines
---
## Introduction
We’ll use the [Instacart dataset](https://tech.instacart.com/3-million-instacart-orders-open-sourced-d40d29ead6f2) 
(also found in [this Kaggle competition](https://www.kaggle.com/c/instacart-market-basket-analysis/)) to 
highlight differences between the query engines found in Cloudera. Instacart is an online grocery delivery service 
headquartered in San Francisco.

## Prerequisites
* Command Line familiarity -- We'll use the shell heavily in this lesson.
* Docker -- This README assumes that you have [Docker](https://www.docker.com) up and running, and, preferably, some 
familiarity with it.
  * In your Docker settings, allocate 8 CPUs and 16 GB of memory.

## 1. Clone and Build this repository (Or, preferably, Load Pre-built Docker Image)
```bash
git clone git@github.com:silicon-valley-data-science/bootcamp.git
cd bootcamp/query-engine-comparison
docker build --force-rm=true -t query-engine-comparison .
```
If you're a Windows user, you'll need to translate the commands above.

However, it is **highly** recommended to load the pre-built Docker image from a thumb drive as it would alleviate the 
problem of everyone simultaneously downloading large files over WiFi as well as help save time:
```bash
docker load -i <directory_path_to>/query-engine-comparison.tar
```

## 2. Copy Dataset
Create a subdirectory to copy/move the *.tar.gz files into. The dataset files should also be included in a thumb drive. 
Otherwise, you'll spend several minutes downloading them from 
[https://tech.instacart.com/3-million-instacart-orders-open-sourced-d40d29ead6f2](https://tech.instacart.com/3-million-instacart-orders-open-sourced-d40d29ead6f2)

Due to the dataset's terms and conditions, we cannot include it in this repository.
```bash
mkdir -p data
mv <directory_path_to>/*.tar.gz data/
```

## 3. Run the Docker Image
```bash
docker run --hostname=quickstart.cloudera --privileged=true -t -i -p 80:80 -p 4040:4040 -p 7180:7180 -p 8888:8888 -p 10000:10000 --name quickstart -v `pwd`/data:/data query-engine-comparison
```
The above command may take several minutes to run as it starts several services. Note that it maps 
the port numbers from Docker to the host machine, so please ensure that you're not running any web server or other 
programs using those ports.

You'll see output messages as the various services are started. When they have all run successfully, the command 
line prompt for the root user in your Docker container will appear. The rest of the lesson will occur on this command 
line as well as your web browser.

## 4. Load the Data
Let's first upload the CSV files to HDFS before defining tables. You may use the Hue web interface, or run the below 
script snippet. If you use Hue, open [http://localhost:8888](http://localhost:8888) in your web browser and login as user 
"cloudera" with password "cloudera" and **please** use the HDFS paths shown in the bash script snippet below.
```bash
for table in "orders" "products" "order_products__prior" "aisles" "departments"
do
    hadoop fs -mkdir -p /user/cloudera/instacart/${table}
    hadoop fs -put /data/${table}.csv /user/cloudera/instacart/${table}/${table}.csv
done
```
In a production system, you'd need to upload your data via the edge node. Or, there would be an ETL process 
loading the data for you.

## 5. Define Tables
We'll use the Hive command line interface (CLI) to define/create the database/schema and tables.
```bash
hive
```
### A. Create Schema
```sql
CREATE SCHEMA instacart;
```
### B. Create Tables
#### i. Set the current working database/schema:
```sql
USE instacart;
```
#### ii. Create the tables in this database/schema:
We define our tables to be **unmanaged** tables that point to a non-default path. This allows the data to be preserved 
even if the table is dropped. In the table properties clause, we specify that the CSV header row should be skipped.
```sql
CREATE EXTERNAL TABLE orders (
  order_id               INT    ,
  user_id                INT    ,
  eval_set               STRING ,
  order_number           INT    ,
  order_dow              TINYINT,
  order_hour_of_day      TINYINT,
  days_since_prior_order DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/cloudera/instacart/orders/'
TBLPROPERTIES ("skip.header.line.count"="1")
;
```
The `products` CSV file has quoted fields, so the CSV serializer-deserializer (serde) needs to be used when creating 
the `products` table. Note that Impala will be unable to read this table, but we'll soon create a Parquet formatted 
copy of this table.
```sql
CREATE EXTERNAL TABLE products (
  product_id    INT   ,
  product_name  STRING,
  aisle_id      INT   ,
  department_id INT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = "," ,
  "quoteChar"     = '"' ,
  "escapeChar"    = "\\"
)
STORED AS TEXTFILE
LOCATION '/user/cloudera/instacart/products/'
TBLPROPERTIES ("skip.header.line.count"="1")
;

CREATE EXTERNAL TABLE order_products__prior (
  order_id          INT    ,
  product_id        INT    ,
  add_to_cart_order INT    ,
  reordered         TINYINT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/cloudera/instacart/order_products__prior/'
TBLPROPERTIES ("skip.header.line.count"="1")
;
```
Exit Hive:
```sql
exit;
```
## 6. Data Transformations in Spark
### A. 
Start the PySpark shell. The command line arguments specify the external libraries needed to parse CSV and output data 
in Avro format.
```bash
pyspark --packages com.databricks:spark-csv_2.10:1.5.0,com.databricks:spark-avro_2.11:3.2.0
```
The below PySpark code reads in the original CSV files from HDFS and outputs Avro and Parquet formatted copies into 
different HDFS directories:
```python
products_df = sqlContext.read.format('com.databricks.spark.csv').options(header='true', inferschema='true').load('/user/cloudera/instacart/products/products.csv')

# File size is small, so only produce 1 part file. This will be the right side of a map join (a.k.a. broadcast join)
products_df.coalesce(1).write.parquet('/user/cloudera/instacart/products_parquet')
products_df.coalesce(1).write.format("com.databricks.spark.avro").save('/user/cloudera/instacart/products_avro')

orders_df = sqlContext.read.format('com.databricks.spark.csv').options(header='true', inferschema='true').load('/user/cloudera/instacart/orders/orders.csv')
orders_df.coalesce(1).write.parquet('/user/cloudera/instacart/orders_parquet')
orders_df.coalesce(1).write.format("com.databricks.spark.avro").save('/user/cloudera/instacart/orders_avro')

order_products__prior_df = sqlContext.read.format('com.databricks.spark.csv').options(header='true', inferschema='true').load('/user/cloudera/instacart/order_products__prior/order_products__prior.csv')

# Because this file/table is large, we do not coalesce into 1 file. Multiple part files will facilitate parallelization even though each part file may still be less than configured HDFS block size.
order_products__prior_df.write.parquet('/user/cloudera/instacart/order_products__prior_parquet')
order_products__prior_df.write.format("com.databricks.spark.avro").save('/user/cloudera/instacart/order_products__prior_avro')

exit()
```
### B.
Exit the PySpark shell and start the Hive CLI. Then, run the below Hive SQL to create the Avro and Parquet versions of 
the tables:
```sql
USE instacart;

CREATE EXTERNAL TABLE products_parquet (
  product_id    INT   ,
  product_name  STRING,
  aisle_id      INT   ,
  department_id INT
)
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/products_parquet/'
;

CREATE EXTERNAL TABLE products_avro (
  product_id    INT   ,
  product_name  STRING,
  aisle_id      INT   ,
  department_id INT
)
STORED AS AVRO
LOCATION '/user/cloudera/instacart/products_avro/'
;

CREATE EXTERNAL TABLE orders_parquet (
  order_id               INT    ,
  user_id                INT    ,
  eval_set               STRING ,
  order_number           INT    ,
  order_dow              TINYINT,
  order_hour_of_day      TINYINT,
  days_since_prior_order DOUBLE
)
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/orders_parquet/'
;

CREATE EXTERNAL TABLE orders_avro (
  order_id               INT    ,
  user_id                INT    ,
  eval_set               STRING ,
  order_number           INT    ,
  order_dow              TINYINT,
  order_hour_of_day      TINYINT,
  days_since_prior_order DOUBLE
)
STORED AS AVRO
LOCATION '/user/cloudera/instacart/orders_avro/'
;

CREATE EXTERNAL TABLE order_products__prior_parquet (
  order_id          INT    ,
  product_id        INT    ,
  add_to_cart_order INT    ,
  reordered         TINYINT
)
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/order_products__prior_parquet/'
;

CREATE EXTERNAL TABLE order_products__prior_avro (
  order_id          INT    ,
  product_id        INT    ,
  add_to_cart_order INT    ,
  reordered         TINYINT
)
STORED AS AVRO
LOCATION '/user/cloudera/instacart/order_products__prior_avro/'
;
```

## 7. Impala and Hive Queries via Hue web interface

Try the following sample query on Impala then Hive:
```sql
SELECT * 
  FROM order_products__prior_parquet AS op
       JOIN orders_parquet AS o
       ON op.order_id = o.order_id
       JOIN products_parquet AS p
       ON op.product_id = p.product_id
;
```
Note how Hive is slower due to translation into MapReduce jobs. Impala is meant for ad-hoc querying (e.g., from BI 
tools like Tableau) while queries and ETL jobs over huge datasets that don’t fit in cluster memory are better suited to 
the more fault-tolerant Hive.

## 8. Execution Engines and Join Optimizations (Hive CLI)
Go back to the Hive command line interface.

Hive has **loads** of configuration options to help you run optimal queries. Here are a few of the main ones:

### A. Execution Engines
You can also set Spark as the execution engine for Hive. MapReduce, the default engine, is comparatively heavier in 
disk I/O. Since Spark does most processing in memory, it may speed up your Hive queries or ETL jobs (although it won’t 
be as fast as Impala).
```sql
USE instacart;
 
SET hive.execution.engine = spark;
 
SELECT * 
  FROM order_products__prior AS op
       JOIN orders AS o
       ON op.order_id = o.order_id
       JOIN products AS p
       ON op.product_id = p.product_id
;
```

### B. Join Optimizations
A good overview of the various Hive join optimizations: 
[https://www.slideshare.net/SzehonHo/hive-join-optimizations-mr-and-spark-53265877](https://www.slideshare.net/SzehonHo/hive-join-optimizations-mr-and-spark-53265877) 

**Data Preparation**

Table statistics are necessary for optimal queries! Check the table stats by running `DESCRIBE FORMATTED <table>;`. 
For example:
```sql
DESCRIBE FORMATTED products_parquet;
```
Now let's compute statistics for the tables:
```sql
ANALYZE TABLE products_parquet COMPUTE STATISTICS;
ANALYZE TABLE orders_parquet COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior_parquet COMPUTE STATISTICS;

ANALYZE TABLE products_avro COMPUTE STATISTICS;
ANALYZE TABLE orders_avro COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior_avro COMPUTE STATISTICS;

ANALYZE TABLE products COMPUTE STATISTICS;
ANALYZE TABLE orders COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior COMPUTE STATISTICS;
```
And check the table stats again:
```sql
DESCRIBE FORMATTED products_parquet;
```

#### i. Map Join
When the right-side relation(s) of a join are significantly smaller than the left-side, it may be more performant to 
“broadcast” the right side to each mapper rather than shuffling the smaller relations through the network. Let's see 
the query plan:
```sql 
EXPLAIN 
SELECT * 
  FROM order_products__prior_parquet AS op
       JOIN orders_parquet AS o
       ON op.order_id = o.order_id
       JOIN products_parquet AS p
       ON op.product_id = p.product_id
;
-- query plan output includes Reducer tasks
```
The query plan output should include Reducer tasks. Next, run:
```sql
SET hive.auto.convert.join = true;
SET hive.auto.convert.join.noconditionaltask.size=999999999;
 
EXPLAIN 
SELECT * 
  FROM order_products__prior_parquet AS op
       JOIN orders_parquet AS o
       ON op.order_id = o.order_id
       JOIN products_parquet AS p
       ON op.product_id = p.product_id
;
-- Now the output no longer should have Reducer tasks
-- Do NOT actually run the query as it’s too large for the -- Docker container with its default Hive settings even with 
-- a LIMIT clause.
```
Now the output no longer should include Reducer tasks. Please do NOT actually run the query as it's too large for the 
Docker container with its default Hive settings (even with a LIMIT clause).

#### ii. Sorted-Merge-Bucket
**Data Preparation**

```sql
CREATE EXTERNAL TABLE order_products__prior_smb (
  order_id          INT    ,
  product_id        INT    ,
  add_to_cart_order INT    ,
  reordered         TINYINT
)
PARTITIONED BY (year INT)
CLUSTERED BY (order_id) SORTED BY (order_id ASC) INTO 2 BUCKETS
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/order_products__prior_smb/'
;

CREATE EXTERNAL TABLE orders_smb (
  order_id               INT    ,
  user_id                INT    ,
  eval_set               STRING ,
  order_number           INT    ,
  order_dow              TINYINT,
  order_hour_of_day      TINYINT,
  days_since_prior_order DOUBLE
)
PARTITIONED BY (year INT)
CLUSTERED BY (order_id) SORTED by (order_id ASC) INTO 2 BUCKETS
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/orders_smb/'
;

SET hive.enforce.bucketing = true;

 INSERT INTO TABLE orders_smb PARTITION (year = 2017)
 SELECT *
   FROM orders_parquet
CLUSTER BY order_id
;

SET hive.execution.engine = mr;

 INSERT INTO TABLE order_products__prior_smb PARTITION (year = 2017)
 SELECT *
   FROM order_products__prior_parquet
CLUSTER BY order_id
;

SET hive.execution.engine = spark;

ANALYZE TABLE orders_smb PARTITION (year = 2017) COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior_smb PARTITION (year = 2017) COMPUTE STATISTICS;
```
The below Hive configuration settings are necessary for inducing a SMB join:
```sql
SET hive.auto.convert.join = true;
SET hive.auto.convert.join.noconditionaltask.size=999999999;
SET hive.auto.convert.sortmerge.join=true;
SET hive.optimize.bucketmapjoin = true;
SET hive.optimize.bucketmapjoin.sortedmerge = true;
 
EXPLAIN
SELECT *
  FROM order_products__prior_smb AS op
       JOIN orders_smb AS o
       ON op.order_id = o.order_id
 WHERE op.year = 2017
       AND o.year = 2017
;
-- query plan output should include “Sorted Merge Bucket Map Join Operator”
```
The query plan output should include "Sorted Merge Bucket Map Join Operator"

Exit the Hive CLI.
```sql
exit;
```

## 9. Spark SQL (PySpark Shell)
```bash
pyspark --packages com.databricks:spark-csv_2.10:1.5.0,com.databricks:spark-avro_2.11:3.2.0
```
Once the PySpark shell has loaded, we'll try the below PySpark code:
```python
products_df = sqlContext.read.format('com.databricks.spark.csv').options(header='true', inferschema='true').load('/user/cloudera/instacart/products/products.csv')
 
products_df.registerTempTable("products")
 
orders_df = sqlContext.read.format('com.databricks.spark.csv').options(header='true', inferschema='true').load('/user/cloudera/instacart/orders/orders.csv')
 
orders_df.registerTempTable("orders")
 
order_products__prior_df = sqlContext.read.format('com.databricks.spark.csv').options(header='true', inferschema='true').load('/user/cloudera/instacart/order_products__prior/order_products__prior.csv')
 
order_products__prior_df.registerTempTable("order_products__prior")
 
query = """
SELECT * 
  FROM order_products__prior AS op
       JOIN orders AS o
       ON op.order_id = o.order_id
       JOIN products AS p
       ON op.product_id = p.product_id
"""
 
join_results = sqlContext.sql(query)
join_results.show()
```
Spark gives you more programmatic control and is well-suited for third-party large-scale machine learning libraries 
such as MLlib or H20.

## EC2 Instructions
```bash
# Modify to your assigned EC2 instance:
export EC2_HOST=ec2-7-0-0-7.eu-west-1.compute.amazonaws.com 

# If ports aren't accessible publicly via http, you may need to include forwarded ports:
ssh -i ~/.ssh/bootcamp-demo.pem demo@${EC2_HOST} -L 4040:${EC2_HOST}:4040 -L 7180:${EC2_HOST}:7180 -L 8888:${EC2_HOST}:8888 -L 10000:${EC2_HOST}:10000
```

