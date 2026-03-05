# Debian系统快速启动指南

## 🚀 前置条件检查

```bash
# 检查Docker是否安装
docker --version

# 检查Docker Compose是否安装
docker-compose --version
# 或 (旧版本)
docker compose version
```

如果未安装，请执行：
```bash
# 安装Docker
sudo apt-get update
sudo apt-get install docker.io

# 安装Docker Compose（选一个）
sudo apt-get install docker-compose
# 或（更新的方式）
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

---

## 🔧 Debian用户权限配置（重要！）

如果你还没有配置过，需要执行以下命令：

```bash
# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 激活新的组成员资格
newgrp docker

# 验证权限
docker ps
# 应该能看到容器列表，不会报权限错误
```

---

## ✅ 最简单的启动方式（3条命令）

```bash
# 1. 进入项目目录
cd /home/yao/fromGithub/mall-swarm

# 2. 给脚本添加执行权限
chmod +x debian-quick-start.sh

# 3. 执行Debian专用启动脚本
./debian-quick-start.sh
```

**脚本会自动：**
- ✅ 检查Docker和Docker Compose
- ✅ 启动所有中间件（MySQL、Redis、RabbitMQ等）
- ✅ 初始化数据库
- ✅ 显示所有访问地址

---

## 🎯 方式1：IDE本地开发启动（推荐）

### 步骤1：确保中间件已启动

```bash
# 检查中间件状态
docker-compose -f ~/mall-swarm/document/docker/docker-compose-env.yml ps

# 应该看到所有容器都是 Up 状态
```

### 步骤2：在IDE中启动微服务

使用IntelliJ IDEA或VS Code，**按照这个顺序**启动各个服务：

#### 1️⃣ Auth服务 (8401)
```
Main class: com.macro.mall.auth.MallAuthApplication
Active profiles: dev
```

静默30秒，等待服务启动后，看到：
```
Registering application mall-auth with eureka with status UP
```

#### 2️⃣ Admin服务 (8080)
```
Main class: com.macro.mall.admin.MallAdminApplication
Active profiles: dev
```

#### 3️⃣ Portal服务 (8085)
```
Main class: com.macro.mall.portal.MallPortalApplication
Active profiles: dev
```

#### 4️⃣ Search服务 (8081)
```
Main class: com.macro.mall.search.MallSearchApplication
Active profiles: dev
```

#### 5️⃣ Gateway服务 (8201)
```
Main class: com.macro.mall.gateway.MallGatewayApplication
Active profiles: dev
```

#### 6️⃣ Monitor服务 (8101) [可选]
```
Main class: com.macro.mall.monitor.MallMonitorApplication
Active profiles: dev
```

**所有服务启动完成后，你会看到：**
```
Started MallGatewayApplication in 12.345 seconds
```

---

## 🐳 方式2：Docker容器启动（快速体验）

```bash
# 启动应用容器
cd /home/yao/fromGithub/mall-swarm/document/docker
docker-compose -f docker-compose-app.yml up -d

# 查看容器状态
docker-compose -f docker-compose-app.yml ps

# 查看日志
docker-compose -f docker-compose-app.yml logs -f mall-admin

# 停止所有服务
docker-compose -f docker-compose-app.yml down
```

---

## 🧪 快速测试

### 测试1：检查Nacos是否运行

```bash
curl -s http://localhost:8848/nacos | head -20
```

如果看到HTML内容，说明Nacos正常运行。

### 测试2：检查MySQL是否就绪

```bash
docker-compose -f document/docker/docker-compose-env.yml exec mysql mysql -uroot -proot -e "SELECT VERSION();"
```

应该输出MySQL版本信息。

### 测试3：测试Admin服务登录（需要启动Admin服务）

```bash
# 登录并获取token
curl -X POST http://localhost:8080/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}'

# 或通过网关
curl -X POST http://localhost:8201/mall-admin/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}'
```

应该返回类似：
```json
{
  "code": 200,
  "message": "操作成功",
  "data": {
    "tokenValue": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600
  }
}
```

---

## 📊 常用命令速查表

### 容器操作

```bash
# 查看所有容器
docker-compose -f document/docker/docker-compose-env.yml ps

# 启动特定容器
docker-compose -f document/docker/docker-compose-env.yml up -d mysql

# 停止特定容器
docker-compose -f document/docker/docker-compose-env.yml stop mysql

# 重启容器
docker-compose -f document/docker/docker-compose-env.yml restart mysql

# 删除容器（停止后）
docker-compose -f document/docker/docker-compose-env.yml rm mysql

# 查看容器日志
docker-compose -f document/docker/docker-compose-env.yml logs mysql

# 实时查看日志
docker-compose -f document/docker/docker-compose-env.yml logs -f mysql

# 执行容器内命令
docker-compose -f document/docker/docker-compose-env.yml exec mysql bash
```

### 清理操作

```bash
# 停止并删除所有容器（保留数据）
docker-compose -f document/docker/docker-compose-env.yml down

# 停止并删除所有容器（包括数据）
docker-compose -f document/docker/docker-compose-env.yml down -v

# 删除所有未使用的镜像和卷
docker system prune -a --volumes
```

### 数据库操作

```bash
# 进入MySQL容器
docker-compose -f document/docker/docker-compose-env.yml exec mysql bash

# MySQL命令行
mysql -uroot -proot

# 查看数据库
SHOW DATABASES;

# 查看表
USE mall;
SHOW TABLES;

# 导入SQL
mysql -uroot -proot mall < document/sql/mall.sql
```

---

## 🔍 访问地址汇总

| 服务 | 地址 | 用户名/密码 | 说明 |
|------|------|-----------|------|
| **Nacos** | http://localhost:8848/nacos | nacos/nacos | 配置中心和服务注册 |
| **MySQL** | localhost:3306 | root/root | 数据库 |
| **Redis** | localhost:6379 | - | 缓存 |
| **RabbitMQ** | http://localhost:15672 | guest/guest | 消息队列管理界面 |
| **Elasticsearch** | http://localhost:9200 | - | 搜索引擎 |
| **Kibana** | http://localhost:5601 | - | 日志查看 |
| **MongoDB** | localhost:27017 | - | 文档数据库 |
| **Admin后台** | http://localhost:8080 | admin/123456 | 后台管理 |
| **Gateway网关** | http://localhost:8201 | - | API网关 |
| **Front门户** | http://localhost:8085 | - | 前台商城 |
| **API文档** | http://localhost:8201/doc.html | - | 所有API文档 |
| **Druid监控** | http://localhost:8080/druid | druid/druid | 数据库监控 |

---

## ⚠️ Debian常见问题解决

### 问题1：Docker权限错误

**错误信息**：
```
permission denied while trying to connect to the Docker daemon
```

**解决**：
```bash
# 添加到docker组
sudo usermod -aG docker $USER
newgrp docker

# 验证
docker ps
```

### 问题2：Docker Compose命令不找到

**错误信息**：
```
command not found: docker-compose
```

**解决**：
```bash
# 检查是否安装了新版本的docker compose
docker compose version

# 如果有，可以创建别名
alias docker-compose='docker compose'

# 或安装旧版本
sudo apt-get install docker-compose
```

### 问题3：容器无法访问本地服务

**症状**：容器内无法连接到 localhost:3306

**解决**：Docker中 localhost 指的是容器本身，应该使用：
- 同网络中的容器名：`mysql:3306`
- 主机名：`host.docker.internal:3306` (某些环境)
- 使用Docker网络：`host` 模式

---

## 🎯 快速对标

如果你之前用过其他项目，这里是启动步骤对比：

```bash
# 传统方式（繁琐）
cd /path/to/project
# 手动启动MySQL、Redis等
# 手动导入SQL
# 编译打包
# 手动配置环境变量
# 逐一启动微服务

# MALL-SWARM方式（简单）
cd mall-swarm
./debian-quick-start.sh  # 一行命令完成所有中间件启动和数据库初始化
# 在IDE中点击"运行"按钮启动各服务
```

---

## 💡 建议

### 仅第一次需要运行
```bash
./debian-quick-start.sh
```

### 日常开发流程
```bash
# 早上只需要启动中间件
docker-compose -f document/docker/docker-compose-env.yml up -d

# 然后在IDE中启动你要开发的服务
# 开发完后关闭IDE

# 晚上关闭中间件
docker-compose -f document/docker/docker-compose-env.yml down
```

### 为了方便，建议添加以下别名（到 ~/.bashrc）
```bash
# 编辑 ~/.bashrc
nano ~/.bashrc

# 添加以下内容
alias mall-start='cd ~/mall-swarm && ./debian-quick-start.sh'
alias mall-stop='docker-compose -f ~/mall-swarm/document/docker/docker-compose-env.yml down'
alias mall-logs='docker-compose -f ~/mall-swarm/document/docker/docker-compose-env.yml logs -f'
alias mall-ps='docker-compose -f ~/mall-swarm/document/docker/docker-compose-env.yml ps'

# 保存后
source ~/.bashrc

# 以后直接用
mall-start  # 启动所有中间件
mall-stop   # 停止所有中间件
mall-logs   # 查看日志
mall-ps     # 查看容器状态
```

---

## ✅ 验证启动成功

如果你看到以下输出，说明一切正常：

```bash
✓ Docker Compose: docker-compose
✓ Docker权限OK
✓ 中间件启动完成

中间件服务信息：
  Nacos:          http://localhost:8848/nacos
  MySQL:          localhost:3306
  Redis:          localhost:6379
  ...
  
✓ MySQL已启动
✓ 数据库初始化完成

===================================
✓ Debian环境启动完成！
===================================
```

---

现在你可以开始开发了！🎉

有任何问题可以参考项目中的详细文档：
- `QUICK_START.md` - 详细启动指南
- `DEVELOPER_GUIDE.md` - 开发者参考
- `IMPROVEMENTS.md` - 项目改进说明
