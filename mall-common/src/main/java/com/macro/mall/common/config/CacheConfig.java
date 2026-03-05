package com.macro.mall.common.config;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.connection.RedisConnectionFactory;

import java.time.Duration;

/**
 * 缓存配置类
 * 集成Spring Cache + Redis实现多层缓存
 * Created by improvement on 2024
 */
@Configuration
@EnableCaching
public class CacheConfig {

    /**
     * 自定义Redis缓存管理器
     * 配置缓存的默认过期时间为24小时
     */
    public CacheManager cacheManager(RedisConnectionFactory factory) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
                // 设置默认过期时间为24小时
                .entryTtl(Duration.ofHours(24))
                // 禁用缓存null值
                .disableCachingNullValues();

        return RedisCacheManager.create(factory);
    }
}
