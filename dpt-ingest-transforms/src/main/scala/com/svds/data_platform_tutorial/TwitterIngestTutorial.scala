package com.svds.data_platform_tutorial

import java.util.Properties
import java.util.concurrent.TimeUnit

import com.typesafe.scalalogging.LazyLogging
import org.apache.kafka.clients.producer.{KafkaProducer, ProducerRecord}
import org.apache.kafka.common.serialization.StringSerializer
import org.apache.spark.SparkConf
import org.apache.spark.rdd.RDD
import org.apache.spark.streaming.{Seconds, StreamingContext}
import org.apache.spark.streaming.twitter.TwitterUtils


object TwitterIngestTutorial extends LazyLogging {

  def main(args: Array[String]): Unit = {

    Helpers.loadTwitterAuthFromFile("/Users/gary/codes/svds/data-platform-tutorial/twitter-secrets.properties")
    Helpers.validateTwitterEnv()

    // set up context
    val conf = new SparkConf()
    .setMaster("local[4]")
    .setAppName("Twitter2Kafka")
    
    // create stream
    val ssc = new StreamingContext(conf, Seconds(5))
    val stream = TwitterUtils.createStream(ssc, twitterAuth = None, filters = Seq("#nba", "nba", "#nfl", "nfl"))
    .repartition(3)
    .map(tweet => (tweet.getId, Converters.tweetToBase64(tweet)))
    // DStream[Long, String]
    
    // todo: come back here later! 
    // process stream
    stream.foreachRDD(publishTweets _)
    
    // some housekeeping
    ssc.start()
    ssc.awaitTermination()
  }

  def publishTweets(tweets: RDD[(Long, String)]): Unit = {
    logger.info(s"will publish ${tweets.count}")
    tweets.foreachPartition { partition =>
      val output = KafkaWriter("kafka:9092", "test_topic")
      partition.foreach { record =>
        output.write(record._1.toString, record._2)
      }
      output.close()
    }
  }

  case class KafkaWriter(brokers: String, topic: String) extends LazyLogging {
    private val config = new Properties() {
      // add configuration settings here.
      put("bootstrap.servers", brokers)
      put("topic", topic)
      put("key.serializer", classOf[StringSerializer])
      put("value.serializer", classOf[StringSerializer])
    }

    val producer = new KafkaProducer[String, String](config)

    // @todo: exercise for reader: make this asynchronous.
    def write(key: String, data: String): Unit = {
      // create record
      val record = new ProducerRecord[String, String](this.topic, key, data)
      // send to producer
      producer.send(record).get(5, TimeUnit.SECONDS)
    }

    def close(): Unit = {
      // close producer.
      producer.close()
    }
  }

}
