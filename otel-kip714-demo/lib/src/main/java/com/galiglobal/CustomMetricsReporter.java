package com.galiglobal;

import org.apache.kafka.common.metrics.KafkaMetric;
import org.apache.kafka.common.metrics.MetricsReporter;
import org.apache.kafka.server.authorizer.AuthorizableRequestContext;
import org.apache.kafka.server.telemetry.ClientTelemetry;
import org.apache.kafka.server.telemetry.ClientTelemetryPayload;
import org.apache.kafka.server.telemetry.ClientTelemetryReceiver;

import java.io.IOException;
import java.util.List;
import java.util.Map;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class CustomMetricsReporter implements MetricsReporter, ClientTelemetry {

    private static final Logger log = LoggerFactory.getLogger(CustomMetricsReporter.class);

    @Override
    public void init(List<KafkaMetric> metrics) {
        log.info("Initializing the metrics");
        // Implement the method to initialize the metrics
    }

    @Override
    public void metricChange(KafkaMetric metric) {
        log.info("Handling the change in a metric");
        // Implement the method to handle the change in a metric
    }

    // Implement the method to handle the removal of a metric
    @Override
    public void metricRemoval(KafkaMetric metric) {
        log.info("Handling the removal of a metric");
        // Implement the method to handle the removal of a metric
    }

    @Override
    public void close() {
        log.info("Closing the reporter");
        // Implement the method to handle the closing of the reporter

    }

    @Override
    public void configure(Map<String, ?> configs) {
        // Implement the method to configure the reporter
        log.info("Configuring the reporter");
    }

    @Override
    public ClientTelemetryReceiver clientReceiver() {
        return new CustomTelemetryReceiver();
    }

    public static class CustomTelemetryReceiver implements ClientTelemetryReceiver {

        // Create an HttpClient
        private final HttpClient client = HttpClient.newHttpClient();

        @Override
        public void exportMetrics(AuthorizableRequestContext authorizableRequestContext, ClientTelemetryPayload clientTelemetryPayload) {
            log.info("CustomTelemetryReceiver: " + authorizableRequestContext);
            log.info("CustomTelemetryReceiver: " + clientTelemetryPayload.clientInstanceId()
                + ": " + clientTelemetryPayload.contentType());

            ByteBuffer byteBuffer = clientTelemetryPayload.data();
            byte[] bytes;

            if (byteBuffer.hasArray()) {
                bytes = byteBuffer.array();
            } else {
                bytes = new byte[byteBuffer.remaining()];
                byteBuffer.get(bytes);
            }

            // Create an HttpRequest
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:4318/v1/metrics"))
                .POST(HttpRequest.BodyPublishers.ofByteArray(bytes))
                .header("Content-Type", "application/x-protobuf")
                .build();

            // Send the HttpRequest and get the response
            HttpResponse<String> response = null;
            try {
                response = client.send(request, HttpResponse.BodyHandlers.ofString());

                log.info("Response status code: " + response.statusCode());
            } catch (IOException e) {
                log.error("Error sending the request: " + e.getMessage());
                throw new RuntimeException(e);
            } catch (InterruptedException e) {
                log.error("Error sending the request: " + e.getMessage());
                throw new RuntimeException(e);
            }
        }
    }
}