# Docker方式启动指南（无需IDE）

## 🚀 快速启动（3步）

### 前置条件检查

```bash
# 检查Docker
docker --version

# 检查Docker Compose
docker compose version

# 检查Maven（用于构建Java项目和Docker镜像）
mvn -v
```

如果缺少Maven，请安装：
```bash
sudo apt-get install maven
```

---

## 📋 启动步骤

### 步骤1：确保中间件在运行

```bash
cd /home/yao/fromGithub/mall-swarm/document/docker

# 查看中间件状态
docker compose -f docker-compose-env.yml ps

# 如果中间件没有运行，启动它
docker compose -f docker-compose-env.yml up -d
```

**确认输出**：所有容器都是 `Up` 状态
```
NAME                COMMAND             SERVICE             STATUS
elasticsearch      docker-entrypoint   elasticsearch       Up
mysql              docker-entrypoint   mysql               Up
redis              redis-server        redis               Up
rabbitmq           docker-entrypoint   rabbitmq            Up
nacos-registry     bin/startup.sh      nacos-registry      Up
...
```

### 步骤2：构建Docker镜像并启动应用

```bash
cd /home/yao/fromGithub/mall-swarm

# 给脚本添加执行权限
chmod +x docker-build-and-run.sh

# 执行脚本（会自动：构建镜像 → 启动容器 → 显示日志）
./docker-build-and-run.sh
```

**期间会问**：
```
是否继续构建Docker镜像？(y/n): 
```

输入 `y` 继续。

### 步骤3：等待应用启动

脚本会：
1. ✅ 编译所有模块
2. ✅ 构建Docker镜像
3. ✅ 启动应用容器
4. ✅ 显示实时日志

看到类似输出说明成功：
```
mall-admin started on port 8080
mall-gateway started on port 8201
...
```

---

## 🧪 验证应用是否运行

打开新的终端：

```bash
# 查看运行的容器
docker compose -f /home/yao/fromGithub/mall-swarm/document/docker/docker-compose-app.yml ps

# 应该能看到：
# mall-admin, mall-gateway, mall-portal, mall-search, mall-auth 都是 Up 状态
```

### 测试API

```bash
# 1. 测试登录
curl -X POST http://localhost:8201/mall-admin/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"123456"}'

# 应该返回包含token的JSON

# 2. 访问API文档
# 浏览器打开：http://localhost:8201/doc.html

# 3. 查询商品
TOKEN="从登录返回的tokenValue"
curl -X GET "http://localhost:8201/mall-admin/product/list?pageNum=1&pageSize=5" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📊 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| API网关 | http://localhost:8201 | 所有API入口 |
| API文档 | http://localhost:8201/doc.html | Swagger API文档 |
| Admin后台 | http://localhost:8080 | 直接访问（无认证） |
| Nacos配置中心 | http://localhost:8848/nacos | nacos/nacos |
| Spring Boot Admin | http://localhost:8101 | 监控面板 |
| Druid数据库监控 | http://localhost:8080/druid | druid/druid |

---

## 🔍 查看日志

脚本启动后会自动显示日志。如果需要手动查看：

```bash
# 查看所有容器的日志
docker compose -f /home/yao/fromGithub/mall-swarm/document/docker/docker-compose-app.yml logs -f

# 查看特定容器的日志
docker compose -f /home/yao/fromGithub/mall-swarm/document/docker/docker-compose-app.yml logs -f mall-admin

# 查看最后100行
docker compose -f /home/yao/fromGithub/mall-swarm/document/docker/docker-compose-app.yml logs --tail=100 mall-admin
```

---

## 🛑 停止应用

```bash
# 停止并删除容器
cd /home/yao/fromGithub/mall-swarm/document/docker
docker compose -f docker-compose-app.yml down

# 删除容器和卷（清理数据）
docker compose -f docker-compose-app.yml down -v

# 保留数据库，只停止容器
docker compose -f docker-compose-app.yml stop
```

---

## 📌 重要说明

### 构建时间
- 首次构建可能需要 **5-15分钟**（取决于网络和机器性能）
- 之后的启动只需几秒钟

### 镜像大小
每个Java应用镜像大约 **500-800MB**，总共需要 **2-3GB** 磁盘空间

### Maven缓存
Maven会在本地缓存依赖。如果网络不稳定，可能需要重试：
```bash
# 强制重新下载依赖
mvn clean install -DskipTests=true -U
```

---

## ⚠️ 常见问题

### 问题1：构建失败

```bash
# 清理并重试
mvn clean
./docker-build-and-run.sh
```

### 问题2：镜像构建后容器无法启动

```bash
# 查看镜像是否存在
docker images | grep mall

# 查看容器日志
docker compose -f document/docker/docker-compose-app.yml logs mall-admin
```

### 问题3：内存不足

镜像构建比较耗内存，如果机器内存不足（<4GB）：

```bash
# 限制Maven内存使用
export MAVEN_OPTS="-Xmx1024m"
./docker-build-and-run.sh
```

### 问题4：网络问题无法下载依赖

```bash
# 使用国内镜像（可选，编辑~/.m2/settings.xml）
# 或重试多次
mvn clean install -DskipTests=true -U
```

---

## 🎯 完整流程总结

```bash
# 1. 进入项目目录
cd /home/yao/fromGithub/mall-swarm

# 2. 确认中间件运行
cd document/docker && docker compose -f docker-compose-env.yml ps

# 3. 执行构建和启动脚本
cd /home/yao/fromGithub/mall-swarm
chmod +x docker-build-and-run.sh
./docker-build-and-run.sh

# 4. 等待应用启动（看到日志输出）
# 按 Ctrl+C 停止日志查看

# 5. 打开新终端验证
curl http://localhost:8201/

# 6. 访问API文档
# 浏览器打开 http://localhost:8201/doc.html
```

---

现在可以开始了！🚀

```bash
cd /home/yao/fromGithub/mall-swarm && chmod +x docker-build-and-run.sh && ./docker-build-and-run.sh
```
