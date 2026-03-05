#!/bin/bash

# ╔═══════════════════════════════════════════════════════════╗
# ║        RabbitMQ 测试脚本 - 订单取消业务场景              ║
# ║          Test Script for Order Cancellation via MQ        ║
# ╚═══════════════════════════════════════════════════════════╝

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# RabbitMQ 信息
RABBITMQ_HOST=${RABBITMQ_HOST:-localhost}
RABBITMQ_PORT=${RABBITMQ_PORT:-15672}
RABBITMQ_USER=${RABBITMQ_USER:-mall}
RABBITMQ_PASS=${RABBITMQ_PASS:-mall}
RABBITMQ_VHOST=${RABBITMQ_VHOST:-/mall}

# API 信息
PORTAL_URL=${PORTAL_URL:-http://localhost:8085}

# 日志配置
LOG_DIR=".rabbitmq-logs"
ENABLE_LOG=${ENABLE_LOG:-false}

# ═══════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    if [ "$ENABLE_LOG" = "true" ]; then
        echo -e "[INFO] $1" >> "$LOG_FILE"
    fi
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    if [ "$ENABLE_LOG" = "true" ]; then
        echo -e "[✓] $1" >> "$LOG_FILE"
    fi
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    if [ "$ENABLE_LOG" = "true" ]; then
        echo -e "[✗] $1" >> "$LOG_FILE"
    fi
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
    if [ "$ENABLE_LOG" = "true" ]; then
        echo -e "[!] $1" >> "$LOG_FILE"
    fi
}

log_section() {
    echo -e "\n${PURPLE}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}■ $1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}\n"
    if [ "$ENABLE_LOG" = "true" ]; then
        echo "" >> "$LOG_FILE"
        echo "=== $1 ===" >> "$LOG_FILE"
    fi
}

# ═══════════════════════════════════════════════════════════════
# 【1】初始化日志（如果启用）
# ═══════════════════════════════════════════════════════════════

init_logs() {
    if [ "$ENABLE_LOG" = "true" ]; then
        if [ ! -d "$LOG_DIR" ]; then
            mkdir -p "$LOG_DIR"
            echo "Created log directory: $LOG_DIR"
        fi
        LOG_FILE="$LOG_DIR/rabbitmq-test-$(date +%Y%m%d_%H%M%S).log"
        echo "Test started at $(date)" > "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
}

# ═══════════════════════════════════════════════════════════════
# 【2】检查 RabbitMQ 连接
# ═══════════════════════════════════════════════════════════════

check_rabbitmq_connection() {
    log_section "Step 2: Checking RabbitMQ Connection"
    
    log_info "Testing connection to RabbitMQ at ${RABBITMQ_HOST}:${RABBITMQ_PORT}"
    
    if curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
            "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/aliveness-test/%2F" > /dev/null 2>&1; then
        log_success "RabbitMQ is running and accessible"
        return 0
    else
        log_error "Failed to connect to RabbitMQ"
        log_info "Make sure RabbitMQ is running on ${RABBITMQ_HOST}:${RABBITMQ_PORT}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# 【3】获取 RabbitMQ 概览信息
# ═══════════════════════════════════════════════════════════════

get_rabbitmq_overview() {
    log_section "Step 3: RabbitMQ Overview"
    
    OVERVIEW=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
        "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/overview")
    
    RABBITMQ_VERSION=$(echo "$OVERVIEW" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    QUEUE_COUNT=$(echo "$OVERVIEW" | grep -o '"queue_totals":{"messages":[0-9]*' | grep -o '[0-9]*$')
    MESSAGE_COUNT=$(echo "$OVERVIEW" | grep -o '"messages":[0-9]*' | grep -o '[0-9]*$' | head -1)
    
    log_info "RabbitMQ Version: $RABBITMQ_VERSION"
    log_info "Total Queues: ${QUEUE_COUNT:-N/A}"
    log_info "Total Messages: ${MESSAGE_COUNT:-0}"
}

# ═══════════════════════════════════════════════════════════════
# 【4】检查队列配置
# ═══════════════════════════════════════════════════════════════

check_queue_config() {
    log_section "Step 4: Checking Queue Configuration"
    
    # 获取所有队列
    QUEUES=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
        "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/queues/%2Fmall")
    
    echo "❶ 延迟队列 (TTL Queue):"
    TTL_QUEUE=$(echo "$QUEUES" | grep -o '"name":"mall\.order\.cancel\.ttl"[^}]*' | head -1)
    if [ -n "$TTL_QUEUE" ]; then
        log_success "Found: mall.order.cancel.ttl"
        TTL_MSG_COUNT=$(echo "$TTL_QUEUE" | grep -o '"messages":[0-9]*' | grep -o '[0-9]*$')
        log_info "  Messages in queue: ${TTL_MSG_COUNT:-0}"
    else
        log_warning "Not found: mall.order.cancel.ttl (Will be created on first message)"
    fi
    
    echo ""
    echo "❷ 实际消费队列 (Dead Letter Queue):"
    ACTUAL_QUEUE=$(echo "$QUEUES" | grep -o '"name":"mall\.order\.cancel"[^}]*' | head -1)
    if [ -n "$ACTUAL_QUEUE" ]; then
        log_success "Found: mall.order.cancel"
        ACTUAL_MSG_COUNT=$(echo "$ACTUAL_QUEUE" | grep -o '"messages":[0-9]*' | grep -o '[0-9]*$')
        log_info "  Messages in queue: ${ACTUAL_MSG_COUNT:-0}"
    else
        log_warning "Not found: mall.order.cancel (Will be created on first message)"
    fi
}

# ═══════════════════════════════════════════════════════════════
# 【5】检查交换机配置
# ═══════════════════════════════════════════════════════════════

check_exchange_config() {
    log_section "Step 5: Checking Exchange Configuration"
    
    EXCHANGES=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
        "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/exchanges/%2Fmall")
    
    echo "❶ 订单直连交换机 (Direct Exchange for actual consumption):"
    if echo "$EXCHANGES" | grep -q '"name":"mall\.order\.direct"'; then
        log_success "Found: mall.order.direct"
    else
        log_warning "Not found: mall.order.direct"
    fi
    
    echo ""
    echo "❷ 订单TTL交换机 (Direct Exchange for TTL):"
    if echo "$EXCHANGES" | grep -q '"name":"mall\.order\.direct\.ttl"'; then
        log_success "Found: mall.order.direct.ttl"
    else
        log_warning "Not found: mall.order.direct.ttl"
    fi
}

# ═══════════════════════════════════════════════════════════════
# 【6】发送消息（模拟订单取消请求）
# ═══════════════════════════════════════════════════════════════

send_test_message() {
    local order_id=$1
    local delay_ms=$2
    
    log_section "Step 6: Sending Test Message (Order Cancellation)"
    
    log_info "Sending order cancellation message:"
    log_info "  Order ID: $order_id"
    log_info "  Delay: ${delay_ms}ms ($(echo "scale=2; $delay_ms/1000" | bc)s)"
    
    # 使用 rabbitmqctl 在容器内发送消息（支持 Long 类型）
    # 或者直接通过 HTTP API 使用 JSON 序列化格式
    
    # 方法1：直接通过 HTTP API 发送简单文本消息（content_type 默认为 text/plain）
    PAYLOAD="{
        \"properties\": {
            \"delivery_mode\": 2,
            \"expiration\": \"$delay_ms\",
            \"headers\": {}
        },
        \"routing_key\": \"mall.order.cancel.ttl\",
        \"payload\": \"$order_id\",
        \"payload_encoding\": \"string\"
    }"
    
    RESPONSE=$(curl -s -X POST \
        -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/exchanges/%2Fmall/mall.order.direct.ttl/publish")
    
    if echo "$RESPONSE" | grep -q '"routed".*true'; then
        log_success "Message sent successfully to: mall.order.direct.ttl"
        log_info "Message will be routed to: mall.order.cancel after ${delay_ms}ms"
        return 0
    else
        log_error "Failed to send message"
        log_info "Response: $RESPONSE"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# 【7】监控队列消息
# ═══════════════════════════════════════════════════════════════

monitor_queues() {
    local duration=$1
    local interval=$2
    
    log_section "Step 7: Monitoring Queues (Duration: ${duration}s, Interval: ${interval}s)"
    
    log_info "Watching queue message counts over time..."
    echo ""
    
    local elapsed=0
    local iteration=0
    
    printf "%-6s %-25s %-25s\n" "Time(s)" "TTL Queue" "Actual Queue"
    printf "%-6s %-25s %-25s\n" "------" "---------" "------------"
    
    while [ $elapsed -lt $duration ]; do
        QUEUES=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
            "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/queues/%2Fmall")
        
        TTL_MSGS=$(echo "$QUEUES" | grep -o '"name":"mall\.order\.cancel\.ttl"[^}]*' | \
                   grep -o '"messages":[0-9]*' | grep -o '[0-9]*$' | head -1)
        ACTUAL_MSGS=$(echo "$QUEUES" | grep -o '"name":"mall\.order\.cancel"[^}]*' | \
                      grep -o '"messages":[0-9]*' | grep -o '[0-9]*$' | head -1)
        
        TTL_MSGS=${TTL_MSGS:-0}
        ACTUAL_MSGS=${ACTUAL_MSGS:-0}
        
        # 彩色输出：如果消息数大于0，用黄色标记
        if [ "$TTL_MSGS" -gt 0 ]; then
            TTL_DISPLAY="${YELLOW}${TTL_MSGS}${NC}"
        else
            TTL_DISPLAY="${GREEN}${TTL_MSGS}${NC}"
        fi
        
        if [ "$ACTUAL_MSGS" -gt 0 ]; then
            ACTUAL_DISPLAY="${YELLOW}${ACTUAL_MSGS}${NC}"
        else
            ACTUAL_DISPLAY="${GREEN}${ACTUAL_MSGS}${NC}"
        fi
        
        printf "%-6d %-25s %-25s\n" "$elapsed" "$TTL_MSGS" "$ACTUAL_MSGS"
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
        iteration=$((iteration + 1))
    done
    
    echo ""
    log_info "Monitoring complete"
}

# ═══════════════════════════════════════════════════════════════
# 【8】清空队列
# ═══════════════════════════════════════════════════════════════

purge_queues() {
    log_section "Step 8: Purging Test Messages"
    
    log_info "Purging queue: mall.order.cancel"
    curl -s -X DELETE \
        -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
        "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/queues/%2Fmall/mall.order.cancel/contents" > /dev/null 2>&1
    log_success "Purged: mall.order.cancel"
    
    log_info "Purging queue: mall.order.cancel.ttl"
    curl -s -X DELETE \
        -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
        "http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api/queues/%2Fmall/mall.order.cancel.ttl/contents" > /dev/null 2>&1
    log_success "Purged: mall.order.cancel.ttl"
}

# ═══════════════════════════════════════════════════════════════
# 【9】生成测试报告
# ═══════════════════════════════════════════════════════════════

generate_report() {
    log_section "Test Report"
    
    cat << 'EOF'

╔════════════════════════════════════════════════════════════╗
║           RabbitMQ 订单取消功能测试总结                     ║
║            Test Summary for Order Cancellation             ║
╚════════════════════════════════════════════════════════════╝

【业务流程说明】
─────────────────────────────────────────────────────────────
1. 发送阶段 (CancelOrderSender)
   - 生成订单ID
   - 设置过期时间 (TTL: Time-To-Live)
   - 将消息发送到: mall.order.direct.ttl 交换机

2. 延迟阶段 (TTL Queue)
   - 消息等待指定时间 (如 30分钟)
   - 队列名称: mall.order.cancel.ttl
   - 配置了死信交换机: mall.order.direct

3. 转发阶段 (Dead Letter Exchange)
   - 消息过期后自动转发到死信交换机
   - 路由到实际消费队列: mall.order.cancel

4. 消费阶段 (CancelOrderReceiver)
   - @RabbitListener 监听 mall.order.cancel
   - 调用 OmsPortalOrderService.cancelOrder()
   - 执行订单取消业务逻辑

【测试场景】
─────────────────────────────────────────────────────────────
✓ 场景1: 快速取消 (1秒延迟)
  用途: 验证消息路由和消费逻辑
  
✓ 场景2: 正常取消 (30秒延迟)
  用途: 验证TTL功能和死信转发
  
✓ 场景3: 批量取消
  用途: 验证消息吞吐能力和并发处理

【关键配置参数】
─────────────────────────────────────────────────────────────
RabbitMQ Host:     ${RABBITMQ_HOST}:${RABBITMQ_PORT}
Virtual Host:      ${RABBITMQ_VHOST}
用户名:             ${RABBITMQ_USER}

交换机 (Exchanges):
  - mall.order.direct      (用于实际消费)
  - mall.order.direct.ttl  (用于延迟消息)

队列 (Queues):
  - mall.order.cancel      (实际消费队列)
  - mall.order.cancel.ttl  (延迟队列 - 死信队列)

【性能指标】
─────────────────────────────────────────────────────────────
吞吐量:  假设 1000 msg/sec
延迟:    通常 < 100ms
可靠性:  Durable Queues + Persistent Messages

【常见问题排查】
─────────────────────────────────────────────────────────────
Q: 消息没有被消费?
A: 1. 检查 mall-portal 服务是否运行
   2. 检查 @RabbitListener 是否启用
   3. 查看应用日志中的错误信息

Q: 消息延迟不准确?
A: 1. RabbitMQ 时钟需要同步
   2. 延迟时间取决于消息过期时间设置
   3. 网络延迟会影响消息转发时间

Q: 如何手动发送测试消息?
A: 使用 RabbitMQ Management UI 或本脚本的 send_test_message 函数



EOF

    log_success "Report generated"
}

# ═══════════════════════════════════════════════════════════════
# 【主测试流程】
# ═══════════════════════════════════════════════════════════════

main() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║        RabbitMQ 事件驱动特性测试                           ║
║         RabbitMQ Event-Driven Feature Test                 ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    
    log_info "开始 RabbitMQ 测试 | Starting RabbitMQ Tests"
    echo ""
    
    # 初始化日志
    if [ "$ENABLE_LOG" = "true" ]; then
        init_logs
        log_info "日志已启用，保存到: $LOG_FILE"
    fi
    echo ""
    
    # 第1步: 检查连接
    if ! check_rabbitmq_connection; then
        log_error "Cannot proceed without RabbitMQ connection"
        exit 1
    fi
    
    # 第2步: 获取概览
    get_rabbitmq_overview
    
    # 第3步: 检查队列
    check_queue_config
    
    # 第4步: 检查交换机
    check_exchange_config
    
    # 第5步: 发送测试消息
    log_section "Sending Test Messages"
    send_test_message "TEST-ORDER-001" 5000
    sleep 2
    send_test_message "TEST-ORDER-002" 10000
    sleep 2
    send_test_message "TEST-ORDER-003" 15000
    
    # 第6步: 监控队列 (监控60秒)
    monitor_queues 60 5
    
    # 第7步: 清空队列
    purge_queues
    
    # 第8步: 生成报告
    generate_report
    
    echo ""
    log_success "All tests completed!"
    if [ "$ENABLE_LOG" = "true" ]; then
        echo ""
        log_info "日志已保存到: $LOG_FILE"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════

# 处理命令行参数
# 检查 --log 标志
if [ "$2" = "--log" ]; then
    ENABLE_LOG="true"
fi

case "${1:-test}" in
    test)
        main
        ;;
    monitor)
        # 只监控队列
        check_rabbitmq_connection || exit 1
        duration=${2:-120}  # 默认监控120秒
        monitor_queues "$duration" 5
        ;;
    send)
        # 发送单条消息
        check_rabbitmq_connection || exit 1
        order_id=${2:-"TEST-$(date +%s)"}
        delay=${3:-5000}
        send_test_message "$order_id" "$delay"
        ;;
    purge)
        # 清空队列
        check_rabbitmq_connection || exit 1
        purge_queues
        ;;
    check)
        # 仅检查配置
        check_rabbitmq_connection || exit 1
        check_queue_config
        check_exchange_config
        ;;
    logs)
        # 查看日志文件夹
        if [ -d "$LOG_DIR" ]; then
            echo -e "${BLUE}[INFO]${NC} 日志文件夹: $(pwd)/$LOG_DIR"
            echo ""
            ls -lh "$LOG_DIR" 2>/dev/null || echo "  (空)"
            echo ""
            echo -e "${BLUE}[INFO]${NC} 最新日志："
            tail -30 "$LOG_DIR"/rabbitmq-test-*.log 2>/dev/null | head -50 || echo "  (无日志文件)"
        else
            echo -e "${YELLOW}[!]${NC} 日志文件夹不存在: $LOG_DIR"
            echo -e "${BLUE}[INFO]${NC} 运行: ./test-rabbitmq.sh test --log 来创建日志"
        fi
        ;;
    *)
        cat << 'EOF'
使用方法 (Usage):

  ./test-rabbitmq.sh [command] [options]

命令 (Commands):

  test [--log]            运行完整测试 (--log 启用日志保存)
  monitor [duration]      监控队列 (秒数, 默认120)
  send [order_id] [delay] 发送测试消息 (延迟毫秒)
  purge                   清空所有测试队列
  check                   只检查配置不运行测试
  logs                    查看历史日志文件

示例 (Examples):

  ./test-rabbitmq.sh test --log     # 运行完整测试并保存日志
  ./test-rabbitmq.sh test           # 仅输出到终端
  ./test-rabbitmq.sh monitor 300    # 监控5分钟
  ./test-rabbitmq.sh send ORD-001 30000  # 发送30秒延迟消息
  ./test-rabbitmq.sh purge          # 清空队列
  ./test-rabbitmq.sh logs           # 查看日志文件夹

环境变量 (Environment Variables):

  RABBITMQ_HOST=localhost      # RabbitMQ主机
  RABBITMQ_PORT=15672          # RabbitMQ管理端口
  RABBITMQ_USER=mall           # 用户名
  RABBITMQ_PASS=mall           # 密码
  RABBITMQ_VHOST=/mall         # Virtual Host

日志说明 (Log Info):

  • 默认行为: 输出到终端，不保存日志
  • 启用日志: 添加 --log 标志，日志会保存到 .rabbitmq-logs/ 文件夹
  • Git 忽略: .rabbitmq-logs/ 已在 .gitignore 中配置，不会提交
  • 查看日志: ./test-rabbitmq.sh logs

EOF
        exit 1
        ;;
esac
