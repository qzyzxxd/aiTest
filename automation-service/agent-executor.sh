#!/usr/bin/env bash
# agent-executor.sh - GitHub Issue 驱动自动化迭代执行器 (优化版)
set -euo pipefail

# ─── 环境准备 ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# 加载配置（如果存在）
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
  source "$SCRIPT_DIR/config.env"
fi

ISSUE_NUM=""
ACTION="opened"

while [[ $# -gt 0 ]]; do
  case $1 in
    --issue) ISSUE_NUM="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$ISSUE_NUM" ]] && { echo "用法: $0 --issue <number>"; exit 1; }

# 日志与状态路径
LOG_DIR="$PROJECT_DIR/logs/automation"
STATE_DIR="$PROJECT_DIR/state/automation"
mkdir -p "$LOG_DIR" "$STATE_DIR"
LOG_FILE="$LOG_DIR/issue-${ISSUE_NUM}.log"
STATE_FILE="$STATE_DIR/issue-${ISSUE_NUM}.json"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# ─── Step 1: 获取 Issue 信息 (使用 GitHub CLI) ──────────────
log "📋 获取 GitHub Issue #${ISSUE_NUM} 信息..."
ISSUE_JSON=$(gh issue view "$ISSUE_NUM" --json title,body,labels 2>/dev/null || echo "")

if [[ -z "$ISSUE_JSON" ]]; then
  log "❌ 无法获取 GitHub Issue #${ISSUE_NUM}，请检查 gh 登录状态或 Repo 权限"
  exit 1
fi

ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))")
ISSUE_BODY=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('body',''))")
log "✅ 需求: $ISSUE_TITLE"

# ─── Step 2: 准备项目上下文 ──────────────────────────────────
log "🔍 扫描项目结构..."
cd "$PROJECT_DIR"
PROJECT_CONTEXT=$(find . -maxdepth 3 -not -path '*/.*' -not -path './node_modules*' | head -n 50)

# ─── Step 3: 优化 Prompt 并调用 AI ──────────────────────────
log "🤖 正在由 AI 生成执行计划与代码..."

PROMPT=$(cat <<EOF
你是一个高级全栈工程师。请根据以下 Issue 需求，为项目生成具体的代码变更。

[项目结构预览]
${PROJECT_CONTEXT}

[需求详情]
Issue: #${ISSUE_NUM} ${ISSUE_TITLE}
描述: ${ISSUE_BODY}

[输出要求]
1. 分析需求，确定需要创建或修改的文件。
2. 给出具体的分支名称（如 feature/issue-${ISSUE_NUM}-xxx）。
3. 给出具体的代码变更列表。
4. 必须输出纯 JSON 格式，结构如下：
{
  "branch": "分支名",
  "summary": "变更摘要",
  "changes": [
    {
      "path": "文件路径",
      "content": "完整的代码内容",
      "method": "overwrite"
    }
  ]
}
EOF
)

# 调用 modelctl route
PLAN=$(echo "$PROMPT" | modelctl route "处理 Issue #${ISSUE_NUM}" 2>/dev/null || echo "")

if [[ -z "$PLAN" ]] || [[ "$PLAN" != *"{"* ]]; then
  log "❌ AI 未能生成有效的 JSON 计划"
  exit 1
fi

# ─── Step 4: 执行变更 ────────────────────────────────────────
BRANCH=$(echo "$PLAN" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('branch', f'feature/issue-${ISSUE_NUM}'))" 2>/dev/null || echo "feature/issue-${ISSUE_NUM}")
log "🌿 创建分支: $BRANCH"

git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

log "⚡ 正在应用代码变更..."
echo "$PLAN" | python3 -c "
import sys, json, os
try:
    data = json.loads(sys.stdin.read())
    for change in data.get('changes', []):
        path = change['path']
        content = change['content']
        if os.path.dirname(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(content)
        print(f'  ✨ 已更新: {path}')
except Exception as e:
    print(f'❌ 解析或写入失败: {e}')
    sys.exit(1)
" | tee -a "$LOG_FILE"

# ─── Step 5: 提交并推送到 GitHub ────────────────────────────
log "📦 提交并推送代码..."
git add .
git commit -m "feat(issue-#${ISSUE_NUM}): ${ISSUE_TITLE}" || true
git push origin "$BRANCH" --force

# ─── Step 6: 创建 GitHub PR ──────────────────────────────────
log "🔀 创建 GitHub Pull Request..."
PR_URL=$(gh pr create --title "feat: $ISSUE_TITLE (Issue #${ISSUE_NUM})" \
               --body "🤖 本 PR 由 PicoClaw 自动化生成。关联 Issue #${ISSUE_NUM}" \
               --base master --head "$BRANCH" 2>/dev/null || gh pr view --json url -q .url || echo "PR_FAILED")

if [[ "$PR_URL" == "PR_FAILED" ]]; then
  log "⚠️  PR 创建失败（可能已存在），尝试获取现有 PR..."
  PR_URL=$(gh pr list --head "$BRANCH" --json url -q '.[0].url' || echo "NONE")
fi

log "✅ PR 已就绪: $PR_URL"

# 在 Issue 中评论
gh issue comment "$ISSUE_NUM" --body "🤖 自动化处理完成！PR 已创建: $PR_URL"

log "🎉 流程结束。"
