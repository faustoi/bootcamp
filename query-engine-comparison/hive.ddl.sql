CREATE SCHEMA instacart;

USE instacart;

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

CREATE EXTERNAL TABLE products (
  product_id    INT,
  product_name  STRING,
  aisle_id      INT,
  department_id INT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = ",",
  "quoteChar"     = '"',
  "escapeChar"    = "\\"
)
STORED AS TEXTFILE
LOCATION '/user/cloudera/instacart/products/'
TBLPROPERTIES ("skip.header.line.count"="1")
;

CREATE EXTERNAL TABLE order_products__prior (
  order_id          INT,
  product_id        INT,
  add_to_cart_order INT,
  reordered         TINYINT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/cloudera/instacart/order_products__prior/'
TBLPROPERTIES ("skip.header.line.count"="1")
;
