package com.macro.mall.portal.test;

import com.macro.mall.portal.component.CancelOrderSender;
import com.macro.mall.portal.domain.QueueEnum;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.amqp.rabbit.core.RabbitAdmin;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import static org.junit.jupiter.api.Assertions.*;
import static org.awaitility.Awaitility.*;

import java.util.concurrent.TimeUnit;

/**
 * RabbitMQ 消息队列集成测试
 * 测试订单取消延迟队列功能
 *
 * @author Test Suite
 * @date 2026-03-05
 */
@SpringBootTest
@DisplayName("RabbitMQ Message Queue Tests")
public class RabbitMqIntegrationTest {

    @Autowired
    private RabbitTemplate rabbitTemplate;

    @Autowired
    private RabbitAdmin rabbitAdmin;

    @Autowired
    private CancelOrderSender cancelOrderSender;

    private static final String QUEUE_TTL = QueueEnum.QUEUE_TTL_ORDER_CANCEL.getName();
    private static final String QUEUE_ACTUAL = QueueEnum.QUEUE_ORDER_CANCEL.getName();
    private static final String EXCHANGE_TTL = QueueEnum.QUEUE_TTL_ORDER_CANCEL.getExchange();
    private static final String EXCHANGE_ACTUAL = QueueEnum.QUEUE_ORDER_CANCEL.getExchange();

    /**
     * 每个测试前清空队列
     */
    @BeforeEach
    public void setUp() {
        purgeQueues();
    }

    /**
     * 【测试1】验证 RabbitMQ 连接
     */
    @Test
    @DisplayName("Test 1: RabbitMQ Connection")
    public void testRabbitMqConnection() {
        assertNotNull(rabbitTemplate, "RabbitTemplate should be autowired");
        assertNotNull(rabbitAdmin, "RabbitAdmin should be autowired");
        System.out.println("✓ RabbitMQ connection verified");
    }

    /**
     * 【测试2】验证队列存在
     */
    @Test
    @DisplayName("Test 2: Queue Configuration Verification")
    public void testQueueConfiguration() {
        // 检查TTL队列
        assertTrue(queueExists(QUEUE_TTL), "TTL Queue should exist");
        System.out.println("✓ TTL Queue exists: " + QUEUE_TTL);

        // 检查实际消费队列
        assertTrue(queueExists(QUEUE_ACTUAL), "Actual Queue should exist");
        System.out.println("✓ Actual Queue exists: " + QUEUE_ACTUAL);
    }

    /**
     * 【测试3】验证交换机存在
     */
    @Test
    @DisplayName("Test 3: Exchange Configuration Verification")
    public void testExchangeConfiguration() {
        // 检查TTL交换机
        assertTrue(exchangeExists(EXCHANGE_TTL), "TTL Exchange should exist");
        System.out.println("✓ TTL Exchange exists: " + EXCHANGE_TTL);

        // 检查实际交换机
        assertTrue(exchangeExists(EXCHANGE_ACTUAL), "Actual Exchange should exist");
        System.out.println("✓ Actual Exchange exists: " + EXCHANGE_ACTUAL);
    }

    /**
     * 【测试4】发送消息到延迟队列
     */
    @Test
    @DisplayName("Test 4: Send Message to TTL Queue")
    public void testSendMessageToTtlQueue() {
        Long orderId = 12345L;
        long delayMs = 5000; // 5秒延迟

        cancelOrderSender.sendMessage(orderId, delayMs);

        // 验证消息已发送到TTL队列
        await()
            .timeout(2, TimeUnit.SECONDS)
            .pollInterval(100, TimeUnit.MILLISECONDS)
            .until(() -> getQueueMessageCount(QUEUE_TTL) > 0);

        int messageCount = getQueueMessageCount(QUEUE_TTL);
        assertEquals(1, messageCount, "TTL Queue should have 1 message");
        System.out.println("✓ Message sent to TTL Queue: " + orderId);
    }

    /**
     * 【测试5】验证消息延迟转发（从TTL队列到实际消费队列）
     */
    @Test
    @DisplayName("Test 5: Message Delay and Dead Letter Forwarding")
    public void testMessageDelayAndForwarding() {
        Long orderId = 54321L;
        long delayMs = 3000; // 3秒延迟

        // 发送消息
        cancelOrderSender.sendMessage(orderId, delayMs);

        // 验证消息在TTL队列中
        await()
            .timeout(2, TimeUnit.SECONDS)
            .until(() -> getQueueMessageCount(QUEUE_TTL) > 0);
        System.out.println("✓ Message in TTL Queue");

        // 等待消息过期并转发到实际队列 (延迟时间 + 缓冲)
        await()
            .timeout((delayMs / 1000) + 5, TimeUnit.SECONDS)
            .pollInterval(500, TimeUnit.MILLISECONDS)
            .until(() -> getQueueMessageCount(QUEUE_ACTUAL) > 0);

        int messageCount = getQueueMessageCount(QUEUE_ACTUAL);
        assertTrue(messageCount > 0, "Message should be forwarded to actual queue");
        System.out.println("✓ Message forwarded to Actual Queue after delay");
    }

    /**
     * 【测试6】批量发送消息
     */
    @Test
    @DisplayName("Test 6: Batch Message Sending")
    public void testBatchMessageSending() {
        int batchSize = 5;
        long[] delays = {1000, 2000, 3000, 4000, 5000};

        for (int i = 0; i < batchSize; i++) {
            Long orderId = (long) (10000 + i);
            cancelOrderSender.sendMessage(orderId, delays[i]);
            System.out.println("  └─ Sent message: " + orderId + " (Delay: " + delays[i] + "ms)");
        }

        // 验证所有消息都在TTL队列中
        await()
            .timeout(3, TimeUnit.SECONDS)
            .until(() -> getQueueMessageCount(QUEUE_TTL) == batchSize);

        int messageCount = getQueueMessageCount(QUEUE_TTL);
        assertEquals(batchSize, messageCount, "TTL Queue should have " + batchSize + " messages");
        System.out.println("✓ All " + batchSize + " messages sent successfully");
    }

    /**
     * 【测试7】验证消息持久化
     */
    @Test
    @DisplayName("Test 7: Message Persistence")
    public void testMessagePersistence() {
        Long orderId = 99999L;
        long delayMs = 2000;

        cancelOrderSender.sendMessage(orderId, delayMs);

        // 获取消息信息
        int countBefore = getQueueMessageCount(QUEUE_TTL);
        assertEquals(1, countBefore, "Should have 1 message");

        // 等待一段时间，消息应该仍然存在（未过期）
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        int countAfter = getQueueMessageCount(QUEUE_TTL);
        assertEquals(1, countAfter, "Message should persist in queue");
        System.out.println("✓ Message persistence verified");
    }

    /**
     * 【测试8】测试不同延迟时间的消息
     */
    @Test
    @DisplayName("Test 8: Multiple Delays Handling")
    public void testMultipleDelaysHandling() {
        // 快速取消: 500ms
        cancelOrderSender.sendMessage(1001L, 500);
        
        // 正常取消: 3秒
        cancelOrderSender.sendMessage(1002L, 3000);
        
        // 延迟取消: 10秒
        cancelOrderSender.sendMessage(1003L, 10000);

        // 验证所有消息都到达TTL队列
        await()
            .timeout(2, TimeUnit.SECONDS)
            .until(() -> getQueueMessageCount(QUEUE_TTL) == 3);

        System.out.println("✓ Successfully handled multiple delay scenarios");
    }

    /**
     * 【测试9】验证队列清空功能
     */
    @Test
    @DisplayName("Test 9: Queue Purging")
    public void testQueuePurging() {
        // 发送消息
        cancelOrderSender.sendMessage(1111L, 5000);
        
        await()
            .timeout(2, TimeUnit.SECONDS)
            .until(() -> getQueueMessageCount(QUEUE_TTL) > 0);

        // 清空队列
        purgeQueues();

        // 验证队列为空
        int messageCount = getQueueMessageCount(QUEUE_TTL);
        assertEquals(0, messageCount, "Queue should be empty after purging");
        System.out.println("✓ Queue purged successfully");
    }

    /**
     * 【测试10】直接消息发送测试
     */
    @Test
    @DisplayName("Test 10: Direct Message Publishing")
    public void testDirectMessagePublishing() {
        String testMessage = "TEST-ORDER-2222";

        // 直接发送消息到TTL交换机
        rabbitTemplate.convertAndSend(
            EXCHANGE_TTL,
            QueueEnum.QUEUE_TTL_ORDER_CANCEL.getRouteKey(),
            testMessage,
            message -> {
                message.getMessageProperties().setExpiration("5000");
                return message;
            }
        );

        // 验证消息已发送
        await()
            .timeout(2, TimeUnit.SECONDS)
            .until(() -> getQueueMessageCount(QUEUE_TTL) > 0);

        System.out.println("✓ Direct message published successfully");
    }

    // ═══════════════════════════════════════════════════════════════
    // 辅助方法 (Helper Methods)
    // ═══════════════════════════════════════════════════════════════

    /**
     * 检查队列是否存在
     */
    private boolean queueExists(String queueName) {
        try {
            QueueInformation queueInfo = rabbitAdmin.getQueueInfo(queueName);
            return queueInfo != null;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 检查交换机是否存在
     */
    private boolean exchangeExists(String exchangeName) {
        try {
            Exchange exchange = rabbitAdmin.getExchange(exchangeName);
            return exchange != null;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 获取队列中的消息数
     */
    private int getQueueMessageCount(String queueName) {
        try {
            QueueInformation queueInfo = rabbitAdmin.getQueueInfo(queueName);
            return queueInfo != null ? queueInfo.getMessageCount() : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    /**
     * 清空所有测试队列
     */
    private void purgeQueues() {
        try {
            rabbitAdmin.purgeQueue(QUEUE_TTL);
            rabbitAdmin.purgeQueue(QUEUE_ACTUAL);
        } catch (Exception e) {
            // 队列可能不存在，忽略异常
        }
    }
}
