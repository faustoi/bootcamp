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
docker run --hostname=quickstart.cloudera --privileged=true -t -i -p 80:80 -p 4040:4040 -p 7180:7180 -p 8888:8888 -p 10000:10000 --name quickstart -v data:/data query-engine-comparison
```
The above command may take several minutes to run as it starts several services and creates tables. Note that it maps 
the port numbers from Docker to the host machine, so please ensure that you're not running any web server or other 
programs using those ports.

You'll see output messages as the various services are started and tables created. When it has all finished successfully, the command 
line prompt for the root user in your Docker container will appear. The rest of the lesson will occur on this command 
line as well as your web browser.

## 4. Impala and Hive Queries via Hue web interface
Open [http://localhost:8888](http://localhost:8888) in your web browser and login as user "cloudera" with password 
"cloudera"

Try the following sample query on Impala then Hive:
```sql
SELECT * 
  FROM order_products__prior AS op
       JOIN orders AS o
       ON op.order_id = o.order_id
       JOIN products AS p
       ON op.product_id = p.product_id
;
```
Note how Hive is slower due to translation into MapReduce jobs. Impala is meant for ad-hoc querying (e.g., from BI 
tools like Tableau) while queries and ETL jobs over huge datasets that don’t fit in cluster memory are better suited to 
the more fault-tolerant Hive.

## 5. Execution Engines and Join Types (Hive CLI)
Run the Hive command line interface
```bash
hive
```
Hive has **loads** of configuration options to help you run optimal queries. Here are a few of the main ones:

### A. Execution Engines
You can also set Spark as the execution engine for Hive. MapReduce, the default engine, is comparatively heavier in 
disk I/O. Since Spark does most processing in memory, it may speed up your Hive queries or ETL jobs, although it won’t 
be as fast as Impala.
```sql
USE instacart;
 
SET hive.execution.engine=spark;
 
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

#### i. Map Join
When the right-side relation(s) of a join are significantly smaller than the left-side, it may be more performant to 
“broadcast” the right side to each mapper rather than shuffling the smaller relations through the network. Let's see 
the query plan:
```sql
USE instacart;
 
SET hive.execution.engine = spark;
 
-- NOTE: Table statistics are important for optimal queries!
-- Check by running “DESCRIBE FORMATTED <table>;”
-- ANALYZE TABLE products_parquet COMPUTE STATISTICS;
-- ANALYZE TABLE orders_parquet COMPUTE STATISTICS;
-- ANALYZE TABLE order_products__prior_parquet COMPUTE STATISTICS;
 
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
Sorted and bucketed tables will have already been pre-populated by the Docker setup shell script, but you should 
familiarize yourself with the creation and insertion of sorted + bucketed table records. Refer to 
```formats.hive.ddl.sql```
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

## 6. Spark SQL (PySpark Shell)
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

