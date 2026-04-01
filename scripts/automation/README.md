# Gitea 驱动自动化迭代工作流

## 架构

```
用户创建 Issue (Gitea)
  → Webhook 触发
    → Webhook 接收器 (/api/webhook/gitea)
      → Agent 分析需求
        → 创建功能分支
          → 执行代码变更
            → 提交并推送
              → 创建 PR
                → 通知用户审核
```

## 组件

| 组件 | 路径 | 说明 |
|------|------|------|
| Webhook 接收器 | `webhook-server.py` | 轻量 HTTP 服务，接收 Gitea Webhook |
| Agent 执行器 | `agent-executor.sh` | 解析 Issue，执行变更，创建 PR |
| 分支管理 | `branch-manager.sh` | 自动创建/清理功能分支 |
| PR 创建器 | `pr-creator.sh` | 自动创建 Pull Request |
| 通知器 | `notifier.sh` | 推送审核通知到飞书 |
| 配置 | `config.env` | Gitea API Token、仓库路径等 |

## 使用

```bash
# 1. 配置
cp config.env.example config.env
# 编辑 config.env 填入 Gitea Token

# 2. 启动 Webhook 服务
./webhook-server.py start

# 3. 手动触发（测试）
./agent-executor.sh --issue 1

# 4. 查看状态
./notifier.sh status
```

## 工作流状态

状态文件保存在 `state/automation/` 目录：
- `pending.json` - 待处理
- `processing.json` - 处理中
- `completed.json` - 已完成
- `failed.json` - 失败
