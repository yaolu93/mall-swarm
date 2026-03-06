package com.macro.mall.portal.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

/**
 * Kafka 订单事件生产者
 * 发布订单相关事件到 Kafka
 */
@Component
public class OrderEventProducer {

    private static final Logger LOGGER = LoggerFactory.getLogger(OrderEventProducer.class);

    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;

    @Value("${kafka.topic.order-events:order-events}")
    private String topic;

    /**
     * 发送订单取消事件
     * @param orderId 订单ID
     */
    public void sendOrderCancelled(Long orderId) {
        try {
            kafkaTemplate.send(topic, "ORDER_CANCELLED:" + orderId);
            LOGGER.info("Published order cancelled event to Kafka: orderId={}", orderId);
        } catch (Exception e) {
            LOGGER.warn("Failed to publish order cancelled event to Kafka: orderId={}", orderId, e);
        }
    }
}