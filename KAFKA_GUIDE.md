# Kafka Integration Guide

This project previously used RabbitMQ for order-cancellation messaging.  Kafka has been added as an additional
asynchronous channel, demonstrating how to publish and consume domain events.

## Architecture

- **Producer**: `OrderEventProducer` publishes simple text events to `order-events` topic.
- **Consumer**: `OrderEventConsumer` listens on the same topic and simply logs received messages.
- **Event format**: `ORDER_CANCELLED:<orderId>`
- **Where**: events are published from `OmsPortalOrderServiceImpl.cancelOrder()` after the database
  update is performed.

## Code changes

### Dependencies
Added `spring-kafka` to `mall-portal/pom.xml`.

```xml
<dependency>
  <groupId>org.springframework.kafka</groupId>
  <artifactId>spring-kafka</artifactId>
</dependency>
```

### Configuration
`mall-portal/src/main/resources/application.yml` now contains Kafka settings:

```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP:localhost:29092}
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer
    consumer:
      group-id: mall-portal-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
```

### Beans
- `KafkaConfig` creates `order-events` topic automatically.
- `OrderEventProducer` wraps `KafkaTemplate<String,String>`.
- `OrderEventConsumer` is a simple listener that logs incoming messages.

### Business integration
`OmsPortalOrderServiceImpl` autowires the producer and calls `sendOrderCancelled(orderId)`
right after successfully canceling an order.

## Docker compose
Kafka broker and Zookeeper have been added to `document/docker/docker-compose-app.yml`:

```yaml
  zookeeper:
    image: bitnami/zookeeper:3.8
    container_name: zookeeper
    environment:
      - ALLOW_ANONYMOUS_LOGIN=yes
    ports:
      - 2181:2181
    networks:
      - mall-network

  kafka:
    image: bitnami/kafka:3
    container_name: kafka
    environment:
      - KAFKA_BROKER_ID=1
      - KAFKA_ZOOKEEPER_CONNECT=zookeeper:2181
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_LISTENERS=PLAINTEXT://:9092
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092
    ports:
      - 9092:9092
    depends_on:
      - zookeeper
    networks:
      - mall-network
```

The `mall-portal` service now sets `KAFKA_BOOTSTRAP=kafka:9092` and waits for the broker to be healthy.

## Testing
A simple manual test can be performed:

1. Start the compose stack:

   ```bash
   docker compose -f document/docker/docker-compose-env.yml \
                  -f document/docker/docker-compose-app.yml up -d kafka zookeeper mall-portal
   ```

2. Trigger a cancellation (e.g. via API or `test-rabbitmq.sh send ...`).
3. Observe the portal logs for `Kafka consumer received message:` entries.

You can also produce events with `kafka-console-producer` and consume with
`kafka-console-consumer` (`docker exec -it kafka ...`).

## Notes
- Kafka is **optional**; existing RabbitMQ functionality remains unchanged.
- This guide can be extended with brokers in other microservices or used for auditing,
  analytics, etc.

---

The addition of Kafka provides a lightweight, event-driven capability that can
be expanded to other subsystems (search index updates, notifications, etc.).

