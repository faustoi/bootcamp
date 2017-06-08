#!/bin/bash -e

spark-submit --packages com.databricks:spark-csv_2.10:1.5.0,com.databricks:spark-avro_2.11:3.2.0 spark.ddl.py
hive -f formats.hive.ddl.sql