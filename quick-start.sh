#!/bin/bash
# 快速启动脚本 - 一键启动所有中间件和微服务

set -e

echo "====================================="
echo "  MALL-SWARM 快速启动脚本"
echo "====================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo -e "${YELLOW}[1/4] 检查Docker和Docker Compose...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装！请先安装Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose未安装！请先安装Docker Compose${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker和Docker Compose已安装${NC}"

# 启动中间件
echo -e "${YELLOW}[2/4] 启动依赖中间件(MySQL、Redis、RabbitMQ、Elasticsearch等)...${NC}"
cd "$PROJECT_ROOT/document/docker"

# 先启动环境容器
docker-compose -f docker-compose-env.yml up -d

echo -e "${GREEN}✓ 中间件启动完成${NC}"
echo ""
echo "中间件服务信息："
echo "  Nacos:          http://localhost:8848/nacos (用户名:nacos 密码:nacos)"
echo "  MySQL:          localhost:3306 (用户名:root 密码:root)"
echo "  Redis:          localhost:6379"
echo "  RabbitMQ:       http://localhost:15672 (用户名:guest 密码:guest)"
echo "  Elasticsearch:  http://localhost:9200"
echo "  Kibana:         http://localhost:5601"
echo "  MongoDB:        localhost:27017"
echo ""

# 数据库初始化
echo -e "${YELLOW}[3/4] 初始化数据库...${NC}"

# 等待MySQL启动
echo "等待MySQL启动..."
for i in {1..30}; do
    if docker-compose -f docker-compose-env.yml exec -T mysql mysql -uroot -proot -e "SELECT 1" &> /dev/null; then
        echo -e "${GREEN}✓ MySQL已启动${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ MySQL启动超时${NC}"
        exit 1
    fi
    sleep 1
done

# 导入SQL
if [ -f "$PROJECT_ROOT/document/sql/mall.sql" ]; then
    echo "导入数据库结构和数据..."
    docker-compose -f docker-compose-env.yml exec -T mysql mysql -uroot -proot < "$PROJECT_ROOT/document/sql/mall.sql"
    echo -e "${GREEN}✓ 数据库初始化完成${NC}"
else
    echo -e "${YELLOW}⚠ SQL文件未找到，跳过数据库初始化${NC}"
fi

echo ""
echo -e "${YELLOW}[4/4] 构建项目...${NC}"

# 返回项目根目录
cd "$PROJECT_ROOT"

# 构建Maven项目
if command -v mvn &> /dev/null; then
    echo "编译和打包项目..."
    mvn clean install -DskipTests=true -q
    echo -e "${GREEN}✓ 项目构建完成${NC}"
else
    echo -e "${YELLOW}⚠ Maven未安装，使用Docker构建...${NC}"
    docker run --rm -v "$PROJECT_ROOT":/workspace -w /workspace maven:3.8.1-openjdk-17 \
        mvn clean install -DskipTests=true -q
    echo -e "${GREEN}✓ 项目构建完成${NC}"
fi

echo ""
echo "====================================="
echo -e "${GREEN}✓ 启动完成！${NC}"
echo "====================================="
echo ""
echo "接下来的步骤："
echo ""
echo "方式1：使用Docker启动应用"
echo "  cd document/docker"
echo "  docker-compose -f docker-compose-app.yml up -d"
echo ""
echo "方式2：本地IDE启动（推荐用于开发）"
echo "  1. 设置active profile为 'dev'"
echo "  2. 在IDE中运行以下主类："
echo "     - MallAdminApplication (port: 8080)"
echo "     - MallAuthApplication (port: 8401)"
echo "     - MallGatewayApplication (port: 8201)"
echo "     - MallPortalApplication (port: 8085)"
echo "     - MallSearchApplication (port: 8081)"
echo "     - MallMonitorApplication (port: 8101)"
echo ""
echo "API网关地址: http://localhost:8201"
echo "API文档: http://localhost:8201/doc.html"
echo ""
echo "测试登录："
echo "  用户名: admin"
echo "  密码: 123456"
echo ""
