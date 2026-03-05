# MALL-SWARM 快速启动和测试指南

## 📚 目录
1. [快速启动](#快速启动)
2. [本地开发环境启动](#本地开发环境启动)
3. [Docker容器启动](#docker容器启动)
4. [API测试](#api测试)
5. [故障排查](#故障排查)

---

## 快速启动

### 一键启动所有服务（推荐）

```bash
# 给脚本添加执行权限
chmod +x quick-start.sh

# 执行启动脚本
./quick-start.sh
```

该脚本会自动：
- ✅ 检查Docker环境
- ✅ 启动所有中间件（MySQL、Redis、RabbitMQ、Elasticsearch、Nacos等）
- ✅ 初始化数据库
- ✅ 编译打包项目

---

## 本地开发环境启动

### 前置条件

确保已安装：
- JDK 17+
- Maven 3.8+
- Docker & Docker Compose（用于中间件）

### 步骤1：启动中间件

```bash
cd document/docker

# 启动环境中间件
docker-compose -f docker-compose-env.yml up -d

# 验证中间件状态
docker-compose -f docker-compose-env.yml ps
```

### 步骤2：初始化数据库

```bash
# 方式1：使用Docker命令
docker-compose -f docker-compose-env.yml exec mysql mysql -uroot -proot < ../sql/mall.sql

# 方式2：手动导入
# 使用MySQL客户端连接到 localhost:3306
# 执行 document/sql/mall.sql 脚本
```

### 步骤3：修改IDE配置

在IDE中（以IntelliJ IDEA为例）：

1. **设置VM Options**（可选，提升启动速度）
   ```
   -Xms1024m -Xmx1024m
   ```

2. **设置环境变量**
   - 右上角 Run → Edit Configurations
   - 点击 `+` 新增Spring Boot配置
   - 创建以下配置项：

#### Admin服务
- **Name**: mall-admin
- **Main class**: com.macro.mall.admin.MallAdminApplication
- **Active profiles**: dev
- **Environment variables**: 
  ```
  ALIYUN_OSS_ENDPOINT=oss-cn-shenzhen.aliyuncs.com;
  ALIYUN_OSS_ACCESS_KEY_ID=test;
  ALIYUN_OSS_ACCESS_KEY_SECRET=test;
  MINIO_ENDPOINT=http://localhost:9000;
  MINIO_ACCESS_KEY=minioadmin;
  MINIO_SECRET_KEY=minioadmin
  ```

#### Gateway服务
- **Name**: mall-gateway
- **Main class**: com.macro.mall.gateway.MallGatewayApplication
- **Active profiles**: dev

#### Auth服务
- **Name**: mall-auth
- **Main class**: com.macro.mall.auth.MallAuthApplication
- **Active profiles**: dev

#### Portal服务
- **Name**: mall-portal
- **Main class**: com.macro.mall.portal.MallPortalApplication
- **Active profiles**: dev

#### Search服务
- **Name**: mall-search
- **Main class**: com.macro.mall.search.MallSearchApplication
- **Active profiles**: dev

#### Monitor服务
- **Name**: mall-monitor
- **Main class**: com.macro.mall.monitor.MallMonitorApplication
- **Active profiles**: dev

### 步骤4：启动服务顺序

**重要**：按照以下顺序启动（等待前一个服务完全启动）：

1. **Nacos+Admin（配置中心）**
   ```
   Nacos会自动在 http://localhost:8848/nacos 启动
   用户名: nacos
   密码: nacos
   ```

2. **Auth服务** (8401端口)
   ```
   登录服务，其他服务依赖此服务
   ```

3. **Admin服务** (8080端口)
   ```
   后台管理服务
   ```

4. **Portal服务** (8085端口)
   ```
   前台商城服务
   ```

5. **Search服务** (8081端口)
   ```
   搜索服务
   ```

6. **Gateway服务** (8201端口)
   ```
   API网关，在此之后启动
   确保所有上游服务已启动
   ```

7. **Monitor服务** (8101端口)
   ```
   可选，用于监控
   ```

### 检查启动日志

启动时查看控制台输出，应该看到：
```
Started MallAdminApplication in 15.234 seconds
Registering application mall-admin with eureka with status UP
```

---

## Docker容器启动

### 启动所有应用服务

```bash
cd document/docker

# 启动应用容器
docker-compose -f docker-compose-app.yml up -d

# 查看容器状态
docker-compose -f docker-compose-app.yml ps

# 查看服务日志
docker-compose -f docker-compose-app.yml logs -f mall-admin
```

### 停止所有服务

```bash
# 停止应用
docker-compose -f docker-compose-app.yml down

# 停止中间件
docker-compose -f docker-compose-env.yml down

# 完全清理（删除数据）
docker-compose -f docker-compose-env.yml down -v
```

---

## API测试

### 1. 获取登录Token

```bash
# 请求
curl -X POST http://localhost:8201/mall-admin/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "123456"
  }'

# 响应示例
{
  "code": 200,
  "message": "操作成功",
  "data": {
    "tokenValue": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "tokenName": "Authorization"
  }
}
```

### 2. 查询商品列表

```bash
# 获取token后
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# 请求1：无分页
curl -X GET "http://localhost:8201/mall-admin/product/list" \
  -H "Authorization: Bearer $TOKEN"

# 请求2：有分页
curl -X GET "http://localhost:8201/mall-admin/product/list?pageNum=1&pageSize=10" \
  -H "Authorization: Bearer $TOKEN"

# 响应
{
  "code": 200,
  "message": "操作成功",
  "data": {
    "total": 28,
    "pageNum": 1,
    "pageSize": 10,
    "list": [
      {
        "id": 1,
        "name": "四季春茶",
        "price": 99.0,
        ...
      }
    ]
  }
}
```

### 3. 查询订单列表

```bash
curl -X GET "http://localhost:8201/mall-admin/order/list?pageNum=1&pageSize=10" \
  -H "Authorization: Bearer $TOKEN"
```

### 4. 创建新商品

```bash
curl -X POST http://localhost:8201/mall-admin/product/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "新商品",
    "description": "商品描述",
    "price": 99.99,
    "stock": 100,
    "categoryId": 1
  }'
```

### 5. 前台API - 用户注册

```bash
curl -X POST http://localhost:8201/mall-portal/sso/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "123456",
    "email": "test@example.com",
    "phone": "13800138000"
  }'
```

### 6. 前台API - 用户登录

```bash
curl -X POST http://localhost:8201/mall-portal/sso/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "123456"
  }'
```

### 7. 搜索API - 搜索商品

```bash
curl -X GET "http://localhost:8201/mall-search/product/search?keyword=茶&pageNum=1&pageSize=10" \
  -H "Authorization: Bearer $TOKEN"
```

---

## API文档

启动所有服务后，访问以下地址查看API文档：

- **网关聚合文档**: http://localhost:8201/doc.html
- **管理后台API**: http://localhost:8080/doc.html
- **前台门户API**: http://localhost:8085/doc.html
- **搜索服务API**: http://localhost:8081/doc.html
- **认证服务API**: http://localhost:8401/doc.html

---

## 故障排查

### 问题1：连接拒绝 (Connection refused)

**症状**：启动时报错 `java.net.ConnectException: Connection refused`

**原因**：中间件未启动或尚未准备好

**解决**：
```bash
# 检查容器状态
docker-compose -f docker-compose-env.yml ps

# 查看容器日志
docker-compose -f docker-compose-env.yml logs mysql

# 重启中间件
docker-compose -f docker-compose-env.yml restart
```

### 问题2：Nacos注册失败

**症状**：日志中出现 `Fail to subscribe service`

**原因**：
- Nacos未启动
- 配置的Nacos地址错误
- 防火墙阻止

**解决**：
```bash
# 访问Nacos管理界面
http://localhost:8848/nacos

# 检查配置
# bootstrap-dev.yml 中的 spring.cloud.nacos.discovery.server-addr
# 应该是：http://localhost:8848 (开发环境)
#      或 http://nacos-registry:8848 (Docker环境)
```

### 问题3：端口被占用

**症状**：启动时报错 `Address already in use`

**解决**：
```bash
# Linux/Mac: 查找占用8080端口的进程
lsof -i :8080

# 杀死进程
kill -9 <PID>

# Windows: 查找占用8080端口的进程
netstat -ano | findstr :8080

# 杀死进程
taskkill /PID <PID> /F
```

### 问题4：数据库连接失败

**症状**：`Access denied for user 'root'@'172.17.0.1'`

**原因**：MySQL容器DNS解析失败

**解决**：
```bash
# 检查MySQL容器
docker-compose -f docker-compose-env.yml logs mysql

# 重启MySQL
docker-compose -f docker-compose-env.yml restart mysql

# 验证连接
docker-compose -f docker-compose-env.yml exec mysql mysql -uroot -proot -e "SELECT 1"
```

### 问题5：Redis连接失败

**症状**：`Redis connection failed`

**解决**：
```bash
# 检查Redis状态
docker-compose -f docker-compose-env.yml exec redis redis-cli ping

# 应该返回：PONG
```

### 问题6：堆内存溢出 (OutOfMemoryError)

**症状**：`java.lang.OutOfMemoryError: Java heap space`

**解决**：
```bash
# 修改IDE运行配置中的VM options
# 从 -Xms512m -Xmx512m
# 改为 -Xms1024m -Xmx2048m

# 或在启动脚本中设置
export JAVA_OPTS="-Xms1024m -Xmx2048m"
```

### 问题7：数据库找不到表

**症状**：启动时报错 `Table 'mall.ums_admin' doesn't exist`

**原因**：SQL脚本未正确导入

**解决**：
```bash
# 手动导入
docker-compose -f docker-compose-env.yml exec mysql mysql -uroot -proot mall < ../sql/mall.sql

# 验证表是否存在
docker-compose -f docker-compose-env.yml exec mysql mysql -uroot -proot -e "USE mall; SHOW TABLES;"
```

### 查看所有日志

```bash
# 查看特定服务日志
docker-compose -f docker-compose-app.yml logs mall-admin

# 实时查看日志
docker-compose -f docker-compose-app.yml logs -f mall-admin

# 查看最后100行日志
docker-compose -f docker-compose-app.yml logs --tail=100 mall-admin
```

---

## 性能测试

### 使用Apache Bench测试

```bash
# 安装ab（如果未安装）
# Mac: brew install httpd
# Linux: sudo apt-get install apache2-utils

# 获取token（替换为实际token）
TOKEN="your-token-here"

# 测试商品列表API
# 100个并发请求，共1000个请求
ab -n 1000 -c 100 \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8201/mall-admin/product/list

# 测试登录API
ab -n 100 -c 10 \
  -p login.json \
  -T application/json \
  http://localhost:8201/mall-admin/admin/login
```

### 使用JMeter测试

```bash
# 安装JMeter后，可以创建测试计划
# 参考文档：https://jmeter.apache.org/usermanual/

# 建议测试场景：
# 1. 登录测试
# 2. 浏览商品列表
# 3. 搜索商品
# 4. 添加购物车
# 5. 下单支付
```

---

## 监控和日志

### 查看实时日志

```bash
# 查看Admin服务日志
curl http://localhost:8080/actuator/health

# 获取详细的健康信息
curl http://localhost:8080/actuator/health | jq

# 查看JVM信息
curl http://localhost:8080/actuator/metrics/jvm.memory.used | jq
```

### Spring Boot Admin监控

访问：http://localhost:8101/

该界面显示：
- 应用列表
- JVM信息
- 内存使用情况
- 线程信息
- 日志查看

### ELK日志查看

访问：http://localhost:5601/

Kibana会自动聚合从Logstash收集的日志。

---

## 常用命令速查表

| 命令 | 说明 |
|-----|------|
| `./quick-start.sh` | 一键启动所有服务 |
| `docker-compose -f docker-compose-env.yml up -d` | 启动中间件 |
| `docker-compose -f docker-compose-app.yml up -d` | 启动应用 |
| `docker-compose -f docker-compose-env.yml ps` | 查看中间件状态 |
| `docker-compose -f docker-compose-env.yml logs -f mysql` | 查看MySQL日志 |
| `docker-compose -f docker-compose-env.yml down` | 停止并删除容器 |
| `mvn clean install -DskipTests=true` | 编译打包（跳过测试） |
| `mvn clean install` | 编译打包（包含测试） |

---

## 下一步

- 📖 查看 [项目改进建议](./IMPROVEMENTS.md)
- 🔧 查看 [配置指南](./CONFIG.md)
- 🚀 查看 [部署指南](./DEPLOYMENT.md)
- 📝 查看 [API文档](http://localhost:8201/doc.html)

