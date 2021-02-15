package com.galiglobal.examples.confluentavro;

import com.galiglobal.examples.testavro.Test;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.errors.SerializationException;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class AvroEmbeddedProducerExample {

    private static final String TOPIC = "test2";
    private static final Properties props = new Properties();

    public static void main(final String[] args) {

        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, 0);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, AvroEmbeddedSerializer.class);

        try (KafkaProducer<String, Test> producer = new KafkaProducer<>(props)) {

            for (long i = 0; i < 10; i++) {
                final String id = "id" + i;
                final Test test = new Test(id, 1000.00d, 1.00d);
                final ProducerRecord<String, Test> record = new ProducerRecord<>(TOPIC, test.getId().toString(), test);
                producer.send(record);
                Thread.sleep(1000L);
            }

            producer.flush();
            System.out.printf("Successfully produced 10 messages to a topic called %s%n", TOPIC);

        } catch (final SerializationException | InterruptedException e) {
            e.printStackTrace();
        }
    }
}
