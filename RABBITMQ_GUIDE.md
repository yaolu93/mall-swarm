# RabbitMQ 订单取消业务实现指南

## 📊 项目总览

本项目使用 **RabbitMQ** 实现了基于**消息驱动架构**的订单自动取消功能，采用**延迟队列 + 死信交换机**的经典模式。

---

## 🏗️ 架构设计

### 核心概念

```
┌─────────────────────────────────────────────────────────────────────┐
│                      消息驱动架构 (Event-Driven)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  【发布侧】                  【消息队列】            【订阅侧】         │
│                                                                       │
│  交易订单系统        →    RabbitMQ           →   订单管理系统      │
│  (CancelOrderSender)    Delay Queue             (CancelOrderReceiver)│
│                                                                       │
│  • 发送订单ID        • TTL设置              • 监听队列             │
│  • 设置延迟时间      • 死信转发              • 执行取消逻辑       │
│  • 异步发送          • 确保可靠性            • 记录日志            │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 消息流向

```
1️⃣ 订单发送阶段
   ↓
   CancelOrderSender.sendMessage(orderId, delayTime)
   ↓
   发送到交换机: mall.order.direct.ttl

2️⃣ 延迟阶段 (TTL Queue 中等待)
   ↓
   队列: mall.order.cancel.ttl
   时间: delayTime 毫秒
   特性: 消息过期后自动进入死信队列

3️⃣ 死信转发阶段
   ↓
   通过死信交换机: mall.order.direct
   转发到: mall.order.cancel

4️⃣ 消费阶段
   ↓
   CancelOrderReceiver @RabbitListener
   执行: OmsPortalOrderService.cancelOrder(orderId)
   结果: 订单状态更新为已取消
```

---

## 📦 代码实现细节

### 1. 队列配置枚举 (QueueEnum.java)

```java
public enum QueueEnum {
    // 实际消费队列
    QUEUE_ORDER_CANCEL(
        "mall.order.direct",           // 交换机名
        "mall.order.cancel",           // 队列名
        "mall.order.cancel"            // 路由键
    ),
    
    // 延迟队列 (TTL)
    QUEUE_TTL_ORDER_CANCEL(
        "mall.order.direct.ttl",       // TTL交换机
        "mall.order.cancel.ttl",       // TTL队列
        "mall.order.cancel.ttl"        // TTL路由键
    );
}
```

| 组件 | 说明 | 用途 |
|------|------|------|
| **Exchange** | 消息分发器 | 根据路由键将消息转发到队列 |
| **Queue** | 消息存储 | 暂存消息，等待消费者处理 |
| **Routing Key** | 路由规则 | 确定消息流向 |

---

### 2. RabbitMQ 配置 (RabbitMqConfig.java)

#### 【交换机配置】

```java
// ① 实际消费交换机 (Direct Exchange)
@Bean
DirectExchange orderDirect() {
    return (DirectExchange) ExchangeBuilder
            .directExchange(QueueEnum.QUEUE_ORDER_CANCEL.getExchange())
            .durable(true)          // 持久化：服务重启后保留
            .build();
}

// ② TTL延迟交换机 (Direct Exchange)
@Bean
DirectExchange orderTtlDirect() {
    return (DirectExchange) ExchangeBuilder
            .directExchange(QueueEnum.QUEUE_TTL_ORDER_CANCEL.getExchange())
            .durable(true)
            .build();
}
```

#### 【队列配置】

```java
// ① 实际消费队列
@Bean
public Queue orderQueue() {
    return new Queue(QueueEnum.QUEUE_ORDER_CANCEL.getName());
}

// ② TTL队列 (带死信配置)
@Bean
public Queue orderTtlQueue() {
    return QueueBuilder
            .durable(QueueEnum.QUEUE_TTL_ORDER_CANCEL.getName())
            // 关键配置：消息过期时自动转发
            .withArgument("x-dead-letter-exchange", 
                QueueEnum.QUEUE_ORDER_CANCEL.getExchange())
            .withArgument("x-dead-letter-routing-key", 
                QueueEnum.QUEUE_ORDER_CANCEL.getRouteKey())
            .build();
}
```

#### 【绑定配置】

```java
// ① 将实际队列绑定到实际交换机
@Bean
Binding orderBinding(DirectExchange orderDirect, Queue orderQueue) {
    return BindingBuilder
            .bind(orderQueue)
            .to(orderDirect)
            .with(QueueEnum.QUEUE_ORDER_CANCEL.getRouteKey());
}

// ② 将TTL队列绑定到TTL交换机
@Bean
Binding orderTtlBinding(DirectExchange orderTtlDirect, Queue orderTtlQueue) {
    return BindingBuilder
            .bind(orderTtlQueue)
            .to(orderTtlDirect)
            .with(QueueEnum.QUEUE_TTL_ORDER_CANCEL.getRouteKey());
}
```

---

### 3. 消息发送者 (CancelOrderSender.java)

```java
@Component
public class CancelOrderSender {
    
    @Autowired
    private AmqpTemplate amqpTemplate;
    
    /**
     * 发送订单取消消息
     * @param orderId    订单ID
     * @param delayTimes 延迟时间 (毫秒)
     */
    public void sendMessage(Long orderId, final long delayTimes) {
        // 发送到TTL交换机
        amqpTemplate.convertAndSend(
            QueueEnum.QUEUE_TTL_ORDER_CANCEL.getExchange(),
            QueueEnum.QUEUE_TTL_ORDER_CANCEL.getRouteKey(),
            orderId,
            new MessagePostProcessor() {
                @Override
                public Message postProcessMessage(Message message) 
                        throws AmqpException {
                    // 关键：设置消息过期时间
                    message.getMessageProperties()
                           .setExpiration(String.valueOf(delayTimes));
                    return message;
                }
            }
        );
        LOGGER.info("send orderId: {}", orderId);
    }
}
```

**关键点说明：**
- `AmqpTemplate.convertAndSend()`: 异步发送消息
- `MessagePostProcessor`: 在发送前修改消息属性
- `setExpiration()`: 设置TTL，单位毫秒

---

### 4. 消息消费者 (CancelOrderReceiver.java)

```java
@Component
@RabbitListener(queues = "mall.order.cancel")  // 监听实际消费队列
public class CancelOrderReceiver {
    
    @Autowired
    private OmsPortalOrderService portalOrderService;
    
    /**
     * 处理订单取消消息
     * @param orderId 订单ID
     */
    @RabbitHandler
    public void handle(Long orderId) {
        // 执行业务逻辑：取消订单
        portalOrderService.cancelOrder(orderId);
        LOGGER.info("process orderId: {}", orderId);
    }
}
```

**关键点说明：**
- `@RabbitListener`: 声明监听的队列
- `@RabbitHandler`: 处理消息的方法
- 消息自动反序列化为 Long 型

---

## 🔄 完整业务流程

### 场景1: 用户下单但30分钟未支付（自动取消）

```
时间线                描述
─────────────────────────────────────────────────────
T=0:00   用户下单
         ├─> 订单状态: 待支付
         └─> CancelOrderSender.sendMessage(orderId, 30*60*1000)
             发送取消消息到TTL队列
             
T=15:00  消息还在延迟队列中
         └─> 队列中的消息计数: 1
         
T=30:00  消息TTL过期
         ├─> 消息自动转发到死信队列
         ├─> CancelOrderReceiver.handle(orderId) 被触发
         └─> 订单状态更新为: 已取消
```

### 场景2: 用户下单后立即支付（取消取消）

```
T=0:00   用户下单
         └─> 发送取消消息到TTL队列
         
T=0:30   用户支付成功
         ├─> 订单状态: 已支付
         ├─> 从TTL队列移除取消消息 (可选)
         └─> 消息最终不会被消费
```

---

## 🧪 测试使用指南

### 方式1: 使用 Shell 脚本测试

```bash
# 获得可执行权限
chmod +x test-rabbitmq.sh

# 运行完整测试
./test-rabbitmq.sh test

# 仅监控队列 (120秒)
./test-rabbitmq.sh monitor 120

# 发送单条测试消息 (30秒延迟)
./test-rabbitmq.sh send TEST-ORDER-001 30000

# 清空队列
./test-rabbitmq.sh purge

# 仅检查配置
./test-rabbitmq.sh check
```

**输出示例：**
```
✓ RabbitMQ is running and accessible
✓ Found: mall.order.cancel.ttl
  Messages in queue: 2
✓ Message sent successfully to: mall.order.direct.ttl
```

### 方式2: 运行 Java 集成测试

```bash
# 运行所有测试
mvn test -Dtest=RabbitMqIntegrationTest

# 运行单个测试
mvn test -Dtest=RabbitMqIntegrationTest#testSendMessageToTtlQueue

# 运行并显示详细输出
mvn test -Dtest=RabbitMqIntegrationTest -X
```

**测试覆盖项：**
- ✓ RabbitMQ 连接
- ✓ 队列配置验证
- ✓ 交换机配置验证
- ✓ 消息发送
- ✓ 消息延迟转发
- ✓ 批量消息处理
- ✓ 消息持久化
- ✓ 队列清空

### 方式3: RabbitMQ 管理界面

访问 http://localhost:15672 (用户名: mall, 密码: mall)

**检查项目：**
1. **Queues** → 查看消息数
2. **Exchanges** → 验证交换机配置
3. **Admin** → 监控连接和通道
4. **Connections** → 查看客户端连接

---

## 🔧 常见问题排查

### Q1: 消息没有被消费

**症状：** 消息发送成功但没有执行取消逻辑

**排查步骤：**
```bash
# 1. 检查 mall-portal 服务是否运行
docker ps | grep mall-portal

# 2. 查看应用日志中有没有错误
docker logs mall-portal | grep -i error

# 3. 检查 @RabbitListener 是否被扫描
docker logs mall-portal | grep "CancelOrderReceiver"

# 4. 查看队列消息数是否减少
./test-rabbitmq.sh monitor 60
```

**常见原因：**
- ❌ Receiver 类未被 Spring 自动装配
- ❌ `@RabbitListener` 注解拼写错误
- ❌ 排除了 spring-amqp 依赖
- ❌ RabbitMQ 连接配置错误

---

### Q2: 消息延迟不准确

**症状：** 消息转发时间与设置的TTL不符

**解决方案：**
```bash
# 同步 RabbitMQ 所在机器的时钟
docker exec rabbitmq ntpdate -s time.nist.gov

# 检查网络延迟
ping rabbitmq-host

# 查看 RabbitMQ 日志
docker logs rabbitmq | tail -100
```

**影响因素：**
- 网络延迟 (通常 10-50ms)
- RabbitMQ 消息处理队列 (高并发场景)
- 操作系统调度延迟

---

### Q3: 消息丢失

**症状：** 发送的消息无法在队列中找到

**检查项：**
```java
// 确保配置了持久化
.durable(true)

// 确保消息也被标记为持久
message.getMessageProperties()
       .setDeliveryMode(MessageDeliveryMode.PERSISTENT);
```

---

## 📈 性能优化建议

### 1. 消费并发控制

```yaml
# application.properties
spring.rabbitmq.listener.simple.concurrency=4           # 最小并发数
spring.rabbitmq.listener.simple.max-concurrency=8       # 最大并发数
spring.rabbitmq.listener.simple.prefetch=1             # 预取消息数
```

### 2. 生产者吞吐优化

```java
// 批量发送
List<Long> orderIds = Arrays.asList(1001L, 1002L, 1003L);
orderIds.forEach(id -> 
    cancelOrderSender.sendMessage(id, 30*60*1000)
);
```

### 3. 错误处理和重试

```java
@RabbitHandler
public void handle(Long orderId) {
    try {
        portalOrderService.cancelOrder(orderId);
    } catch (Exception e) {
        LOGGER.error("Failed to cancel order: {}", orderId, e);
        // 重试逻辑或死信处理
    }
}
```

---

## 📚 依赖配置

### Maven POM

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.amqp</groupId>
    <artifactId>spring-amqp</artifactId>
</dependency>
```

### Spring Boot Properties

```properties
# RabbitMQ 连接配置
spring.rabbitmq.host=localhost
spring.rabbitmq.port=5672
spring.rabbitmq.username=mall
spring.rabbitmq.password=mall
spring.rabbitmq.virtual-host=/mall

# 连接池配置
spring.rabbitmq.connection-factory.cache-mode=CONNECTION
spring.rabbitmq.connection-factory.connection-cache-size=10

# 监听器配置
spring.rabbitmq.listener.simple.prefetch=1
spring.rabbitmq.listener.simple.concurrency=4
```

---

## 🎯 总结

| 特性 | 说明 |
|------|------|
| **延迟机制** | TTL (Time-To-Live) 队列 |
| **可靠性** | 死信队列 + 消息持久化 |
| **并发能力** | 支持多消费者并发处理 |
| **扩展性** | 易于添加新的消费者 |
| **监控** | RabbitMQ 管理界面实时查看 |

---

## 参考资源

- [Spring AMQP 文档](https://spring.io/projects/spring-amqp)
- [RabbitMQ 官方文档](https://www.rabbitmq.com/documentation.html)
- [RabbitMQ 最佳实践](https://www.rabbitmq.com/best-practices.html)

---

**更新于:** 2026-03-05  
**作者:** Test Suite
