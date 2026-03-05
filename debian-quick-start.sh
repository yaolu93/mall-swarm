#!/bin/bash
# Debian系统快速启动脚本 - 为已安装Docker Compose的用户优化

set -e

echo "====================================="
echo "  MALL-SWARM Debian快速启动脚本"
echo "====================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

# 检查Docker Compose命令
check_docker_compose() {
    # 优先检查新版本的 docker compose
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        echo -e "${RED}❌ 未找到Docker Compose，请先安装${NC}"
        echo "  Debian安装命令: sudo apt-get install docker-compose-plugin"
        echo "  或: sudo apt-get install docker-compose"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Compose: $DOCKER_COMPOSE${NC}"
}

# 检查Docker权限
check_docker_permission() {
    if ! docker ps &> /dev/null; then
        echo -e "${RED}❌ 无权限访问Docker，请执行以下命令添加当前用户到docker组：${NC}"
        echo "  sudo usermod -aG docker \$USER"
        echo "  newgrp docker"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker权限OK${NC}"
}

echo ""
echo -e "${YELLOW}[1/3] 检查Docker环境...${NC}"
check_docker_compose
check_docker_permission

# 启动中间件
echo ""
echo -e "${YELLOW}[2/3] 启动依赖中间件...${NC}"
cd "$PROJECT_ROOT/document/docker"

# 先启动环境容器
echo "启动MySQL、Redis、RabbitMQ、Elasticsearch等..."
$DOCKER_COMPOSE -f docker-compose-env.yml up -d

echo -e "${GREEN}✓ 中间件启动完成${NC}"
echo ""
echo "中间件服务信息："
echo "  Nacos:          http://localhost:8848/nacos (用户名:nacos 密码:nacos)"
echo "  MySQL:          localhost:3306 (用户名:root 密码:root)"
echo "  Redis:          localhost:6379"
echo "  RabbitMQ:       http://localhost:15672 (guest/guest)"
echo "  Elasticsearch:  http://localhost:9200"
echo "  MongoDB:        localhost:27017"
echo ""

# 数据库初始化
echo -e "${YELLOW}[3/3] 初始化数据库...${NC}"

# 等待MySQL启动
echo "等待MySQL启动..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if $DOCKER_COMPOSE -f docker-compose-env.yml exec -T mysql mysql -uroot -proot -e "SELECT 1" &> /dev/null; then
        echo -e "${GREEN}✓ MySQL已启动${NC}"
        break
    fi
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}❌ MySQL启动超时${NC}"
        echo "  检查日志: $DOCKER_COMPOSE -f docker-compose-env.yml logs mysql"
        exit 1
    fi
    sleep 1
done

# 导入SQL
if [ -f "$PROJECT_ROOT/document/sql/mall.sql" ]; then
    echo "创建数据库..."
    $DOCKER_COMPOSE -f docker-compose-env.yml exec -T mysql mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS mall DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    
    echo "导入数据库结构和数据..."
    $DOCKER_COMPOSE -f docker-compose-env.yml exec -T mysql mysql -uroot -proot mall < "$PROJECT_ROOT/document/sql/mall.sql"
    
    echo -e "${GREEN}✓ 数据库初始化完成${NC}"
    
    # 验证导入是否成功
    echo "验证数据库..."
    table_count=$($DOCKER_COMPOSE -f docker-compose-env.yml exec -T mysql mysql -uroot -proot mall -e "SHOW TABLES;" 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ 导入了 $((table_count - 1)) 个表${NC}"
else
    echo -e "${RED}❌ SQL文件未找到: $PROJECT_ROOT/document/sql/mall.sql${NC}"
    exit 1
fi

echo ""
echo "====================================="
echo -e "${GREEN}✓ Debian环境启动完成！${NC}"
echo "====================================="
echo ""
echo "接下来的步骤："
echo ""
echo -e "${BLUE}方式1：使用IDE启动微服务（推荐用于开发）${NC}"
echo "  1. 在IDE中打开项目"
echo "  2. 按照以下顺序启动服务："
echo "     → MallAuthApplication (8401) - 认证服务"
echo "     → MallAdminApplication (8080) - 后台管理"
echo "     → MallPortalApplication (8085) - 前台商城"
echo "     → MallSearchApplication (8081) - 搜索服务"
echo "     → MallGatewayApplication (8201) - API网关"
echo "     → MallMonitorApplication (8101) - 监控（可选）"
echo ""
echo -e "${BLUE}方式2：使用Docker启动应用${NC}"
echo "  cd document/docker"
echo "  $DOCKER_COMPOSE -f docker-compose-app.yml up -d"
echo ""
echo -e "${BLUE}方式3：快速测试（无需启动应用）${NC}"
echo "  # 等待MySQL启动后直接测试API"
echo "  curl http://localhost:8848 && echo 'Nacos OK'"
echo ""
echo "常用命令："
echo "  查看容器状态: $DOCKER_COMPOSE -f docker-compose-env.yml ps"
echo "  查看日志: $DOCKER_COMPOSE -f docker-compose-env.yml logs -f mysql"
echo "  停止服务: $DOCKER_COMPOSE -f docker-compose-env.yml down"
echo "  清理数据: $DOCKER_COMPOSE -f docker-compose-env.yml down -v"
echo ""
echo "API访问地址:"
echo "  API文档: http://localhost:8201/doc.html (需启动网关服务)"
echo "  Nacos管理: http://localhost:8848/nacos"
echo "  Druid监控: http://localhost:8080/druid (需启动admin服务)"
echo ""
