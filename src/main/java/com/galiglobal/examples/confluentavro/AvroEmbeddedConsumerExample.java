package com.galiglobal.examples.confluentavro;

import com.galiglobal.examples.testavro.Test;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class AvroEmbeddedConsumerExample {

    private static final String TOPIC = "test2";
    private static final Properties props = new Properties();

    public static void main(final String[] args) {

        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "test-embedded");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "true");
        props.put(ConsumerConfig.AUTO_COMMIT_INTERVAL_MS_CONFIG, "1000");
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

        StringDeserializer stringDeserializer = new StringDeserializer();
        AvroEmbeddedDeserializer<Test> avroEmbeddedDeserializer = new AvroEmbeddedDeserializer<>(Test.class);

        try (final KafkaConsumer<String, Test> consumer = new KafkaConsumer<>(props, stringDeserializer, avroEmbeddedDeserializer)) {
            consumer.subscribe(Collections.singletonList(TOPIC));

            while (true) {
                final ConsumerRecords<String, Test> records = consumer.poll(Duration.ofMillis(100));
                for (final ConsumerRecord<String, Test> record : records) {
                    final String key = record.key();
                    final Test value = record.value();
                    System.out.printf("key = %s, value = %s%n", key, value);
                }
            }
        }
    }
}
