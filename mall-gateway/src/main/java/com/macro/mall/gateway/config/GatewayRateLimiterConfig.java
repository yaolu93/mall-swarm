package com.macro.mall.gateway.config;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import reactor.core.publisher.Mono;

/**
 * 网关限流配置类
 * 使用Spring Cloud Gateway的内置RateLimiter实现限流
 * 
 * 配置在gateway的application.yml中：
 * 
 * spring:
 *   cloud:
 *     gateway:
 *       routes:
 *         - id: mall-admin
 *           uri: lb://mall-admin
 *           predicates:
 *             - Path=/mall-admin/**
 *           filters:
 *             - name: RequestRateLimiter
 *               args:
 *                 redis-rate-limiter.replenish-rate: 100      # 每秒请求数
 *                 redis-rate-limiter.requested-tokens: 1      # 每个请求消耗token数
 *                 key-resolver: '#{@ipAddressKeyResolver}'    # 按IP限流
 *             - StripPrefix=1
 *         
 *         - id: mall-portal
 *           uri: lb://mall-portal
 *           predicates:
 *             - Path=/mall-portal/**
 *           filters:
 *             - name: RequestRateLimiter
 *               args:
 *                 redis-rate-limiter.replenish-rate: 50
 *                 redis-rate-limiter.requested-tokens: 1
 *                 key-resolver: '#{@ipAddressKeyResolver}'
 *             - StripPrefix=1
 * 
 * Created by improvement on 2024
 */
@Configuration
public class GatewayRateLimiterConfig {

    /**
     * 基于IP地址的限流策略
     * 不同IP地址的请求分别计算限流
     */
    @Bean
    @Primary
    public KeyResolver ipAddressKeyResolver() {
        return exchange -> Mono.just(
                exchange.getRequest().getRemoteAddress() != null ?
                        exchange.getRequest().getRemoteAddress().getAddress().getHostAddress() :
                        "unknown"
        );
    }
}
