from pyspark import SparkContext, SparkConf
from pyspark.sql import SQLContext

conf = SparkConf()
sc = SparkContext(conf=conf)
sqlContext = SQLContext(sc)

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