USE instacart;

CREATE EXTERNAL TABLE products_parquet (
  product_id    INT,
  product_name  STRING,
  aisle_id      INT,
  department_id INT
)
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/products_parquet/'
;

CREATE EXTERNAL TABLE products_avro (
  product_id    INT,
  product_name  STRING,
  aisle_id      INT,
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
  order_id          INT,
  product_id        INT,
  add_to_cart_order INT,
  reordered         TINYINT
)
STORED AS PARQUET
LOCATION '/user/cloudera/instacart/order_products__prior_parquet/'
;

CREATE EXTERNAL TABLE order_products__prior_avro (
  order_id          INT,
  product_id        INT,
  add_to_cart_order INT,
  reordered         TINYINT
)
STORED AS AVRO
LOCATION '/user/cloudera/instacart/order_products__prior_avro/'
;

SET hive.execution.engine = spark;

ANALYZE TABLE products_parquet COMPUTE STATISTICS;
ANALYZE TABLE orders_parquet COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior_parquet COMPUTE STATISTICS;

ANALYZE TABLE products_avro COMPUTE STATISTICS;
ANALYZE TABLE orders_avro COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior_avro COMPUTE STATISTICS;

ANALYZE TABLE products COMPUTE STATISTICS;
ANALYZE TABLE orders COMPUTE STATISTICS;
ANALYZE TABLE order_products__prior COMPUTE STATISTICS;

CREATE EXTERNAL TABLE order_products__prior_smb (
  order_id          INT,
  product_id        INT,
  add_to_cart_order INT,
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
