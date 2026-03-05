#!/bin/bash
# Docker镜像构建和启动脚本 - 无需IDE

set -e

echo "====================================="
echo "  MALL-SWARM Docker镜像构建脚本"
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
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        echo -e "${RED}❌ 未找到Docker Compose，请先安装${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Compose: $DOCKER_COMPOSE${NC}"
}

# 检查Maven
check_maven() {
    if ! command -v mvn &> /dev/null; then
        echo -e "${RED}❌ Maven未安装，请先安装Maven${NC}"
        echo "  Debian安装: sudo apt-get install maven"
        exit 1
    fi
    echo -e "${GREEN}✓ Maven: $(mvn -v | head -1)${NC}"
}

# 构建Docker镜像
build_docker_images() {
    echo ""
    echo -e "${YELLOW}[2/3] 使用Maven构建Docker镜像...${NC}"
    
    cd "$PROJECT_ROOT"
    
    # 构建所有模块（包含Docker镜像）
    echo "编译和构建所有模块..." 
    mvn clean install -DskipTests=true -Ddocker.skip=false
    
    echo -e "${GREEN}✓ Docker镜像构建完成${NC}"
    
    # 验证镜像
    echo ""
    echo "已构建的镜像："
    docker images | grep mall || echo "未找到mall镜像"
}

# 启动应用容器
start_app_containers() {
    echo ""
    echo -e "${YELLOW}[3/3] 启动应用容器...${NC}"
    
    cd "$PROJECT_ROOT/document/docker"
    
    echo "启动中间件和应用服务（合并网络）..."
    # 使用 -f 合并两个 compose 文件，这样它们会共享同一个网络，服务名可以互相解析
    $DOCKER_COMPOSE -f docker-compose-env.yml -f docker-compose-app.yml up -d
    
    echo -e "${GREEN}✓ 应用容器启动完成${NC}"
}

# 显示日志
show_logs() {
    echo ""
    echo "应用启动中，显示日志（按Ctrl+C退出）..."
    sleep 5
    $DOCKER_COMPOSE -f "$PROJECT_ROOT/document/docker/docker-compose-app.yml" logs -f
}

# 检查环境
echo -e "${YELLOW}[1/3] 检查构建环境...${NC}"
check_docker_compose
check_maven

# 询问是否构建
read -p "是否继续构建Docker镜像？(y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消构建"
    exit 0
fi

# 构建镜像
build_docker_images

# 启动容器
start_app_containers

# 显示信息
echo ""
echo "====================================="
echo -e "${GREEN}✓ Docker应用已启动！${NC}"
echo "====================================="
echo ""
echo "访问地址："
echo "  API网关: http://localhost:8201"
echo "  API文档: http://localhost:8201/doc.html"
echo "  Admin后台: http://localhost:8080"
echo "  监控面板: http://localhost:8101"
echo ""
echo "常用命令："
echo "  查看容器: $DOCKER_COMPOSE -f document/docker/docker-compose-app.yml ps"
echo "  查看日志: $DOCKER_COMPOSE -f document/docker/docker-compose-app.yml logs -f"
echo "  停止服务: $DOCKER_COMPOSE -f document/docker/docker-compose-app.yml down"
echo ""
echo "按 Ctrl+C 可以停止日志输出"
echo ""

# 显示实时日志
show_logs
