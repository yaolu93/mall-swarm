package com.macro.mall.portal.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

/**
 * Kafka 订单事件消费者
 * 消费订单相关事件并进行处理
 */
@Component
public class OrderEventConsumer {

    private static final Logger LOGGER = LoggerFactory.getLogger(OrderEventConsumer.class);

    /**
     * 监听订单事件
     * @param message 消息内容
     */
    @KafkaListener(topics = "${kafka.topic.order-events:order-events}")
    public void listen(String message) {
        LOGGER.info("Kafka consumer received message: {}", message);
        // 这里可以添加具体的业务处理逻辑
        // 例如：发送通知、更新统计、触发下游服务等
    }
}