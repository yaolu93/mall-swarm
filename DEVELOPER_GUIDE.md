# 开发者快速参考指南

## 🚀 5分钟快速启动

### 最快速的方式（推荐！）

```bash
# 1. 进入项目目录
cd /home/yao/fromGithub/mall-swarm

# 2. 执行一键启动脚本
chmod +x quick-start.sh
./quick-start.sh

# 3. 启动完成后，在IDE中依次运行以下主类（按顺序）：
#    - MallAuthApplication (8401)
#    - MallAdminApplication (8080)  
#    - MallPortalApplication (8085)
#    - MallSearchApplication (8081)
#    - MallGatewayApplication (8201)
#    - MallMonitorApplication (8101)  [可选]
```

---

## 📋 项目结构一览

```
mall-swarm/
├── mall-common/        # 通用模块（AOP、异常处理、缓存、链追踪等）
├── mall-mbg/          # MyBatis代码生成器输出
├── mall-admin/        # 后台管理系统 (8080)
├── mall-auth/         # 认证中心 (8401)
├── mall-gateway/      # API网关 (8201)
├── mall-portal/       # 前台商城系统 (8085)
├── mall-search/       # 搜索服务 (8081)
├── mall-monitor/      # 监控中心 (8101)
├── mall-demo/         # 远程调用测试
├── config/            # Nacos配置（可选）
├── document/
│   ├── docker/        # Docker Compose配置
│   ├── k8s/          # Kubernetes部署配置
│   └── sql/          # 数据库脚本
├── pom.xml           # 主pom文件
├── quick-start.sh    # 一键启动脚本
├── QUICK_START.md    # 详细启动指南
└── postman_collection.json  # API测试集合
```

---

## 🔧 配置要点

### 1. 环境变量配置（生产环境必设）

```bash
# 敏感信息都应该通过环境变量注入，不要硬编码

export DB_HOST=db
export DB_USERNAME=reader
export DB_PASSWORD=123456
export REDIS_HOST=redis
export REDIS_PORT=6379
export REDIS_PASSWORD=
export JWT_SECRET_KEY=your-secret-key
export ALIYUN_OSS_ENDPOINT=oss-cn-shenzhen.aliyuncs.com
export ALIYUN_OSS_ACCESS_KEY_ID=your-access-key
export ALIYUN_OSS_ACCESS_KEY_SECRET=your-secret
export MINIO_ENDPOINT=http://minio:9000
export MINIO_ACCESS_KEY=minioadmin
export MINIO_SECRET_KEY=minioadmin
```

### 2. 数据库初始化

```bash
# 自动方式（推荐）
docker-compose -f document/docker/docker-compose-env.yml exec mysql mysql -uroot -proot < document/sql/mall.sql

# 手动方式
# 1. 使用MySQL客户端连接到 localhost:3306
# 2. 执行 document/sql/mall.sql 脚本
```

### 3. Nacos配置中心

```bash
# 访问Nacos管理界面
http://localhost:8848/nacos

# 登录信息
用户名: nacos
密码: nacos

# 在Nacos中创建配置（可选，会自动加载）
namespace: public
data-id: mall-admin-dev.yaml
group: DEFAULT_GROUP
content: （复制config/admin/mall-admin-dev.yaml的内容）
```

---

## 🧪 快速测试

### 方式1：使用cURL（最简单）

```bash
# 1. 登录获取token
TOKEN=$(curl -s -X POST http://localhost:8201/mall-admin/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}' | jq -r '.data.tokenValue')

echo "Token: $TOKEN"

# 2. 使用token查询商品列表
curl -X GET "http://localhost:8201/mall-admin/product/list?pageNum=1&pageSize=5" \
  -H "Authorization: Bearer $TOKEN"
```

### 方式2：使用Postman

```bash
# 1. 导入Postman集合
# 打开Postman → Import → 选择 postman_collection.json

# 2. 设置环境变量
# 在Postman中创建Environment，设置以下变量：
# - adminToken: （从登录API获取）
# - userToken: （从前台登录API获取）

# 3. 逐个运行API测试
```

### 方式3：使用IDE REST工具

**IntelliJ IDEA** 内置了HTTP测试工具：

1. 在项目中创建 `api.http` 文件
2. 添加以下内容：

```http
### 登录
POST http://localhost:8201/mall-admin/admin/login
Content-Type: application/json

{
  "username": "admin",
  "password": "123456"
}

### 查询商品列表
GET http://localhost:8201/mall-admin/product/list?pageNum=1&pageSize=5
Authorization: Bearer YOUR_TOKEN_HERE

### 创建商品
POST http://localhost:8201/mall-admin/product/create
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN_HERE

{
  "name": "新商品",
  "price": 99.99,
  "stock": 100,
  "categoryId": 1,
  "brandId": 1
}
```

3. 点击绿色运行按钮执行请求

---

## 📊 系统架构关键要点

### 认证流程

```
用户请求 → 网关(8201) 
    ↓
检查白名单 → 不需要认证
    ↓
需要认证 → 检查Authorization header
    ↓
验证token → Auth服务(8401)
    ↓
检查权限 → Sa-Token
    ↓
转发到对应微服务
```

### 服务通信

```
Admin(8080) ←→ Feign远程调用 ←→ Auth(8401)
Admin(8080) ←→ Feign远程调用 ←→ Portal(8085)
Admin(8080) ←→ Feign远程调用 ←→ Search(8081)

所有服务 ← 通过Nacos服务注册发现
```

### 缓存策略

```
热点数据: Redis @Cacheable
     ↓
缓存预热: 应用启动时加载常用数据
     ↓
缓存失效: 修改数据时清除 @CacheEvict
     ↓
缓存击穿: 使用布隆过滤器（可选）
     ↓
缓存雪崩: 设置合理的TTL和失效时间
```

---

## 🔍 日志查看

### 本地IDE开发

```
Console → 实时日志输出
可以在IDE控制台直接看到所有日志
```

### Docker环境

```bash
# 查看特定服务日志
docker-compose -f document/docker/docker-compose-app.yml logs -f mall-admin

# 查看最后100行
docker-compose -f document/docker/docker-compose-app.yml logs --tail=100 mall-admin

# 查看所有容器日志
docker-compose -f document/docker/docker-compose-app.yml logs -f
```

### ELK日志分析

```bash
# Kibana访问地址
http://localhost:5601

# 创建索引模式
Index pattern: logstash-*
Time field: @timestamp
```

---

## ⚡ 性能优化检查清单

- [x] Druid连接池配置优化（慢查询日志已启用）
- [x] Sa-Token超时时间缩短为1小时
- [x] Redis缓存已配置
- [x] 敏感信息已移至环境变量
- [ ] 数据库查询优化（可继续优化索引）
- [ ] 热点方法添加@Cacheable（可选）
- [ ] 异步处理（可选，在BaseService中支持）
- [ ] 分布式链追踪（已添加Sleuth配置）

---

## 🐛 常见问题速查

| 问题 | 快速解决 |
|-----|---------|
| 端口被占用 | `lsof -i :8080` 然后 `kill -9 <PID>` |
| MySQL连接失败 | `docker-compose restart mysql` |
| Redis连接失败 | `docker-compose exec redis redis-cli ping` |
| Nacos连接失败 | 检查 `spring.cloud.nacos.discovery.server-addr` |
| Token过期 | 重新登录获取新token |
| 权限不足(403) | 检查用户角色和权限配置 |
| 数据库表不存在 | 重新导入SQL: `docker-compose exec mysql mysql -uroot -proot mall < sql/mall.sql` |
| 堆内存不足 | IDE或启动脚本添加 `-Xmx2048m` |

---

## 📚 重要文件位置

| 文件 | 位置 | 说明 |
|-----|------|------|
| 环境配置 | `mall-admin/src/main/resources/application-prod.yml` | 生产配置，敏感信息用环境变量 |
| 日志配置 | `document/elk/logback-spring.xml` | 日志输出配置 |
| 数据库 | `document/sql/mall.sql` | 初始化脚本 |
| Docker | `document/docker/*.yml` | 容器编排 |
| Kubernetes | `document/k8s/*.yaml` | K8s部署 |

---

## 🎯 下一步建议

1. **阅读详细文档**
   - [QUICK_START.md](./QUICK_START.md) - 完整启动指南
   - [项目改进详情](#) - 已实现的改进

2. **API开发**
   - 访问 http://localhost:8201/doc.html 查看API文档
   - 使用Postman测试API
   - 参考现有Controller写法开发新API

3. **性能优化**
   - 检查慢查询日志：http://localhost:8080/druid
   - 监控内存使用：http://localhost:8101
   - 查看应用指标：http://localhost:8080/actuator/metrics

4. **部署上线**
   - 参考 `document/k8s/` 配置Kubernetes部署
   - 配置生产环境环境变量
   - 设置适当的资源限制和自动扩展

---

## 💡 小提示

- 开发时建议在IDE中启动服务，便于调试
- 使用 `dev` 活跃配置进行开发
- 生产环境必须使用 `prod` 活跃配置
- 定期检查依赖更新和安全漏洞
- 写好单元测试和集成测试

祝你开发愉快！🎉

