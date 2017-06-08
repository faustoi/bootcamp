package com.svds.data_platform_tutorial

import com.typesafe.scalalogging.LazyLogging
import org.apache.spark.sql.SparkSession

object BatchTransformTutorial extends LazyLogging {
  
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      // Set master, app name, and cassandra host
        .master("local[4]")
        .appName("Batch")
        .config("spark.cassandra.connection.host", "cassandra")
      .getOrCreate()

    import spark.implicits._

    val raw = spark.read
        .format("kafka")
        .option("kafka.bootstrap.servers", "kafka:9092")
        .option("subscribe", "test_topic")
      // format, kafka bootstrap servers, topic
      .load()

    logger.info("Raw input looks like:")
    raw.show()

    val tweets = raw
      // filter
        .filter("key is not null")
      // cast value to string
        .selectExpr("cast(value as string)")
      // make into Dataset of String
        .as[String]
      // map base 64 encoded tweet string into fields
        .map { base64Tweet =>
      val tweet = Converters.base64ToTweet(base64Tweet)
      (tweet.getId, tweet.getCreatedAt.getTime, tweet.getUser.getScreenName, tweet.getText.filter( _ >= ' '))
    }
      .toDF("id", "when", "sender", "value")

    // register udf
    spark.udf.register("termSearch", Helpers.termSearch("nba", "nfl"))

    val withTerm = tweets // select columns and explode of udf in order wanted for output
    .selectExpr("id", "when", "sender", "explode(termSearch(value)) as term", "value")

    logger.info("Transformed looks like:")
    withTerm.show()

    // write to csv with header
    withTerm.write.option("header", "true").mode("overwrite").csv("tweets-batch")

    spark.stop()
  }
}
