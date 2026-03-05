package com.macro.mall.common.config;

import org.springframework.context.annotation.Configuration;

/**
 * 分布式链追踪配置
 * 功能：记录分布式系统中的请求链路，便于问题排查和性能监控
 * 
 * 使用方法：
 * 1. 添加spring-cloud-starter-sleuth依赖（已在pom.xml中）
 * 2. 可选：添加spring-cloud-starter-zipkin用于可视化展示
 * 3. 配置日志：确保日志包含traceId和spanId
 * 
 * 日志输出格式示例：
 * [mall-admin,08f81d9fbf3f4f89,08f81d9fbf3f4f89,true] INFO  - request processed
 *  ^^^^^^^^^  ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^  ^^^^
 *   应用名     traceId           spanId           导出标记
 * 
 * Created by improvement on 2024
 */
@Configuration
public class SleuthConfig {
    
    /**
     * Sleuth配置在application.yml中：
     * 
     * spring:
     *   sleuth:
     *     sampler:
     *       probability: 1.0  # 采样概率（生产环境建议0.1）
     *     trace-id128: true   # 使用128位traceId（与Zipkin兼容）
     *   
     *   zipkin:
     *     base-url: http://localhost:9411/  # Zipkin服务地址
     *     sender:
     *       type: web  # 使用HTTP方式发送数据
     * 
     * 
     * 生产环境配置（application-prod.yml）：
     * spring:
     *   sleuth:
     *     sampler:
     *       probability: 0.1  # 降低采样概率以减少性能影响
     *   zipkin:
     *     base-url: http://${ZIPKIN_URL:zipkin:9411}/
     */
}
