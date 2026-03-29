# DevOps 自动化演示项目

## 🎯 项目目标

演示完整的软件开发生命周期自动化流程：

```
需求 → 开发 → PR → 审查 → 合并 → 测试 → 发布 → 监控 → 问题反馈 → 新需求
```

## 🔄 完整流程

### 1. 需求整理
- 用户通过 Gitea Issues 提交需求
- AI 自动分析和分类需求
- 自动创建标签和里程碑

### 2. 开发
- 基于 Issue 创建分支
- 本地开发和测试
- 推送代码并创建 PR

### 3. PR 审查
- 自动化代码检查
- AI 代码审查
- 团队成员人工审查

### 4. 合并
- 通过审查后自动合并到主分支
- 触发 CI/CD 流水线

### 5. 测试
- 自动化单元测试
- 集成测试
- 端到端测试

### 6. 发布
- 自动构建 Docker 镜像
- 推送到镜像仓库
- 部署到生产环境

### 7. 监控
- 应用健康检查
- 性能监控
- 错误追踪

### 8. 反馈循环
- 监控数据自动分析
- 发现问题自动创建 Issue
- 重新开始需求整理

## 🛠️ 技术栈

- **代码管理**: Gitea
- **CI/CD**: GitHub Actions
- **容器化**: Docker
- **监控**: Prometheus + Grafana
- **日志**: ELK Stack
- **自动化**: 脚本 + AI Agent

## 📁 项目结构

```
devops-demo/
├── app/                    # 应用代码
│   ├── src/               # 源代码
│   ├── tests/             # 测试代码
│   └── Dockerfile         # 容器化配置
├── .github/               # GitHub Actions 工作流
│   └── workflows/        # CI/CD 配置
├── scripts/               # 自动化脚本
│   ├── issue-triage.sh   # Issue 分类
│   ├── auto-review.sh    # 自动审查
│   ├── deploy.sh         # 部署脚本
│   └── monitor.sh        # 监控脚本
├── infrastructure/        # 基础设施代码
│   ├── docker-compose.yml
│   └── terraform/
└── docs/                 # 文档
    ├── workflow.md       # 流程文档
    └── api.md            # API 文档
```

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone https://gitea.smalldong.top/smalldong/devops-demo.git
cd devops-demo
```

### 2. 启动应用
```bash
docker-compose up -d
```

### 3. 访问应用
- 主应用: http://localhost:8080
- 监控面板: http://localhost:3000
- 日志面板: http://localhost:5601

## 🔄 使用流程

### 创建新需求
1. 在 Gitea 创建 Issue
2. 系统自动分类和标记
3. AI 分析需求并生成实现方案

### 开始开发
```bash
# 基于 Issue 创建分支
./scripts/create-branch.sh issue-123

# 开发完成后推送并创建 PR
git push origin feature/issue-123-new-feature
./scripts/create-pr.sh issue-123
```

### 自动化流程
- PR 创建后自动触发 CI
- 测试通过后自动审查
- 审查通过后自动合并
- 合并后自动部署

### 监控和反馈
- 系统持续监控应用状态
- 发现问题自动创建 Issue
- 触发新一轮需求整理

## 📊 监控指标

- 应用健康状态
- 响应时间
- 错误率
- 用户行为数据
- 系统资源使用

## 🔔 告警机制

- 应用异常告警
- 性能下降告警
- 错误率超标告警
- 安全漏洞告警

## 🎯 成功指标

- 需求到发布时间缩短 50%
- Bug 发现和修复时间减少 60%
- 部署频率提升 300%
- 代码质量提升 40%

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交变更
4. 推送到分支
5. 创建 Pull Request

## 📄 许可证

MIT License