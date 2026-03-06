package com.macro.mall.portal.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class KafkaConfig {
    @Value("${kafka.topic.order-events:order-events}")
    private String orderEventsTopic;

    @Bean
    public NewTopic orderEventsTopic() {
        return new NewTopic(orderEventsTopic, 1, (short) 1);
    }
}