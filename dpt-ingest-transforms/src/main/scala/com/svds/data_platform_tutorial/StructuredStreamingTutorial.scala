package com.svds.data_platform_tutorial

import java.util.concurrent.Executors

import com.datastax.spark.connector.cql.CassandraConnector
import com.typesafe.scalalogging.LazyLogging
import org.apache.spark.sql.{ForeachWriter, Row, SparkSession}
import org.apache.spark.sql.functions.{expr, window}

import scala.concurrent.{ExecutionContext, Future}


object StructuredStreamingTutorial extends LazyLogging {

  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .master("local[4]")
      .appName("Structured Streaming Transform Tutorial")
      .config("spark.cassandra.connection.host", "cassandra")
      .getOrCreate()

    import spark.implicits._

    val raw = spark.readStream // <-- change to readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "kafka:9092")
      .option("subscribe", "test_topic")
      .load()

    val tweets = raw
      .filter("key is not null") // ignore console producer messages
      .selectExpr("CAST(value AS STRING)")
      .as[String]
      .map { base64Tweet =>
        val tweet = Converters.base64ToTweet(base64Tweet)
        (tweet.getId, tweet.getCreatedAt.getTime, tweet.getUser.getScreenName, tweet.getText.filter(_ >= ' '))
      }
      .toDF("id", "when", "sender", "value")

    // Create CassandraConnector
    val connector = CassandraConnector(spark.sparkContext)
    val statement = "insert into demo.raw_tweets (id, when, sender, value) values (?,?,?,?)"
    logger.info("Submitting raw tweet ingest query")
    // write stream using CassandraWriter
    val rawIngest = tweets.writeStream
        .outputMode("append")
        .foreach(CassandraWriter(connector, statement))
        .start()


    spark.udf.register("termSearch", Helpers.termSearch("nba", "nfl"))
    val statement2 = "insert into demo.window_snapshots (when, term, value) values (?,?,?)"
    logger.info("Submitting windowed counts query")
    // Write windowed counts to cassandra
    val windowed = tweets
    // - convert when to timestamp
    .withColumn("ts", expr("cast(when / 1000 as timestamp)"))
    // - register watermark
    .withWatermark("ts", "2 minutes")
    // - search for terms
    .selectExpr("ts", "explode(termSearch(value)) as term")
    // - group by window and term and get count
    .groupBy(window($"ts", "1 minute", "5 seconds").as("w"), $"term").count()
    // - convert to expected schema
    .selectExpr("cast(w.start as bigint) * 1000 as when", "term", "cast(count as int) as count")
    // - write stream with CassandraWriter
    .writeStream
        .outputMode("update")
    .foreach(CassandraWriter(connector, statement2))
    .start()


    logger.info("Waiting for termination")
    // wait for termination
    rawIngest.awaitTermination()
  }

  case class CassandraWriter(connector: CassandraConnector, statement: String) extends ForeachWriter[Row] {
    def open(partitionId: Long, version: Long): Boolean = true

    def process(value: Row): Unit = connector.withSessionDo { session =>
      val pstmt = session.prepare(statement)
      val bound = pstmt.bind(value.toSeq.map(_.asInstanceOf[Object]) : _*)
      session.execute(bound)
    }

    def close(errorOrNull: Throwable): Unit = ()
  }
}

