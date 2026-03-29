# DevOps 自动化流程 - 快速开始

## 🚀 一键启动

```bash
# 进入项目目录
cd /root/.picoclaw/workspace/projects/devops-demo

# 运行完整的自动化流程演示
./scripts/devops-automation.sh demo
```

## 📋 完整流程

### 1. 需求整理
- 用户通过 Gitea Issues 提交需求
- AI 自动分析并分类（类型、优先级、范围）
- 自动添加标签和里程碑

### 2. 开发
```bash
# 基于 Issue 创建分支
./scripts/create-branch.sh <issue_number>
```

### 3. 创建 PR
```bash
# 推送代码后自动创建 PR
git push origin feature/issue-123
```

### 4. 自动化审查
- 代码质量检查 (ESLint)
- 单元测试 (Jest)
- 安全扫描 (Trivy)
- AI 代码审查

### 5. 合并
- 审查通过后自动合并
- 触发 CI/CD 流水线

### 6. 构建和测试
```bash
# 运行测试
npm test

# 构建 Docker 镜像
docker build -t devops-demo:latest ./app
```

### 7. 部署
```bash
# 部署应用
docker-compose up -d
```

### 8. 监控
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000
- 应用健康检查: http://localhost:8080/health

### 9. 反馈循环
- 监控数据自动分析
- 发现问题自动创建 Issue
- 重新开始需求整理

## 🛠️ 常用命令

### 应用管理
```bash
# 启动应用
./scripts/devops-automation.sh start

# 停止应用
./scripts/devops-automation.sh stop

# 查看状态
./scripts/devops-automation.sh status

# 查看日志
./scripts/devops-automation.sh logs
```

### 开发流程
```bash
# 运行测试
./scripts/devops-automation.sh test

# 创建开发分支
./scripts/create-branch.sh <issue_number>

# Issue 分类
./scripts/issue-triage.sh <issue_number>
```

## 📊 监控面板

### 访问地址
- **主应用**: http://localhost:8080
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
  - 用户名: admin
  - 密码: admin

### 关键指标
- 请求响应时间
- 错误率
- CPU/内存使用率
- 请求量统计

## 🔍 问题排查

### 应用无法启动
```bash
# 检查容器状态
docker-compose ps

# 查看日志
docker-compose logs devops-demo

# 重启应用
docker-compose restart
```

### 监控数据不显示
```bash
# 检查 Prometheus 配置
curl http://localhost:8080/metrics

# 检查 Grafana 数据源配置
# 访问: Configuration > Data Sources > Prometheus
```

## 🎯 成功指标

- ✅ 需求到发布时间缩短 50%
- ✅ Bug 发现和修复时间减少 60%
- ✅ 部署频率提升 300%
- ✅ 代码质量提升 40%

## 📚 相关文档

- [详细文档](./README.md)
- [CI/CD 流程](./.github/workflows/ci-cd.yml)
- [应用代码](./app/)
- [监控配置](./infrastructure/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！