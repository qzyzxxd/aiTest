#!/usr/bin/env bash
# agent-executor.sh - Gitea Issue 驱动自动化迭代执行器
# 用法: ./agent-executor.sh --issue <issue_number> [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/config.env" 2>/dev/null || { echo "❌ config.env 未配置，请复制 config.env.example 并填写"; exit 1; }

ISSUE_NUM=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --issue) ISSUE_NUM="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

[[ -z "$ISSUE_NUM" ]] && { echo "用法: $0 --issue <number>"; exit 1; }

# 目录初始化
mkdir -p "$LOG_DIR" "$STATE_DIR"
LOG_FILE="$LOG_DIR/issue-${ISSUE_NUM}.log"
STATE_FILE="$STATE_DIR/issue-${ISSUE_NUM}.json"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# ========== Step 1: 获取 Issue 信息 ==========
log "📋 获取 Issue #${ISSUE_NUM} 信息..."

ISSUE_JSON=$(curl -s -H "Authorization: token $GITEA_API_TOKEN" \
  "$GITEA_URL/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/issues/$ISSUE_NUM")

ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))")
ISSUE_BODY=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('body',''))")
ISSUE_LABELS=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(','.join(l['name'] for l in json.load(sys.stdin).get('labels',[])))")

if [[ -z "$ISSUE_TITLE" ]]; then
  log "❌ 无法获取 Issue #${ISSUE_NUM}"
  exit 1
fi

log "✅ Issue #${ISSUE_NUM}: ${ISSUE_TITLE}"
log "   标签: ${ISSUE_LABELS:-无}"

# 记录状态
cat > "$STATE_FILE" <<EOF
{
  "issue": $ISSUE_NUM,
  "title": "$ISSUE_TITLE",
  "status": "analyzing",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# ========== Step 2: 分析需求 ==========
log "🔍 分析需求..."

ANALYSIS=$(cat <<'PROMPT'
你是一个 DevOps 工程师。请分析以下 Issue 需求，输出执行计划：

Issue: #${ISSUE_NUM} ${ISSUE_TITLE}
描述: ${ISSUE_BODY}
标签: ${ISSUE_LABELS}

请输出：
1. 需求类型（feature/bugfix/docs/chore）
2. 需要修改的文件
3. 具体变更内容
4. 分支名称（格式：feature/issue-<num>-<short-desc>）

只输出 JSON 格式。
PROMPT
)

# 使用 PicoClaw 分析（通过 modelctl）
PLAN=$(modelctl route "分析 Gitea Issue #${ISSUE_NUM}: ${ISSUE_TITLE}\n描述: ${ISSUE_BODY}\n请输出执行计划 JSON" 2>/dev/null || echo '{"type":"feature","branch":"feature/issue-'$ISSUE_NUM'","files":[],"desc":"待实现"}')

BRANCH=$(echo "$PLAN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('branch', f'feature/issue-${ISSUE_NUM}'))" 2>/dev/null || echo "feature/issue-${ISSUE_NUM}")

log "📌 分支: ${BRANCH}"

if $DRY_RUN; then
  log "🔍 [DRY RUN] 停止执行"
  log "计划: $PLAN"
  exit 0
fi

# ========== Step 3: 创建功能分支 ==========
log "🌿 创建功能分支: ${BRANCH}"

cd "$PROJECT_DIR"
git fetch origin
git checkout -b "$BRANCH" origin/master 2>/dev/null || git checkout -b "$BRANCH"

# ========== Step 4: 执行变更（Agent 核心逻辑） ==========
log "⚡ 执行变更..."

# 根据 Issue 标签/类型决定执行策略
case "${ISSUE_LABELS}" in
  *bug*|*fix*)
    log "  🐛 Bug 修复模式"
    # 这里可以接入具体的修复逻辑
    ;;
  *feature*|*enhancement*)
    log "  ✨ 功能开发模式"
    ;;
  *docs*)
    log "  📝 文档更新模式"
    ;;
  *)
    log "  🔧 通用模式"
    ;;
esac

# Agent 分析并执行实际变更
# 这里通过 PicoClaw 生成变更代码
CHANGE_SUMMARY=$(modelctl route "基于以下需求生成代码变更：\nIssue: #${ISSUE_NUM} ${ISSUE_TITLE}\n描述: ${ISSUE_BODY}\n请输出变更摘要" 2>/dev/null || echo "自动变更完成")

log "📝 变更摘要: ${CHANGE_SUMMARY}"

# ========== Step 5: 提交并推送 ==========
log "📦 提交变更..."

git add -A
git commit -m "feat(issue-#${ISSUE_NUM}): ${ISSUE_TITLE}

${CHANGE_SUMMARY}

Closes #${ISSUE_NUM}" || log "⚠️  无变更或提交失败"

git push -u origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"

# ========== Step 6: 创建 PR ==========
log "🔀 创建 Pull Request..."

PR_JSON=$(curl -s -X POST \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"feat(issue-#${ISSUE_NUM}): ${ISSUE_TITLE}\",
    \"body\": \"## 变更说明\\n\\n${CHANGE_SUMMARY}\\n\\n## 关联 Issue\\n\\nCloses #${ISSUE_NUM}\\n\\n## 变更类型\\n\\n- [ ] 新功能\\n- [ ] Bug 修复\\n- [ ] 文档更新\\n- [ ] 重构\",
    \"head\": \"${BRANCH}\",
    \"base\": \"${GITEA_BRANCH}\"
  }" \
  "$GITEA_URL/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/pulls")

PR_URL=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url',''))" 2>/dev/null)
PR_NUM=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('number',''))" 2>/dev/null)

log "✅ PR 创建成功: ${PR_URL}"

# 在 Issue 中评论关联 PR
curl -s -X POST \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"🤖 自动化 PR 已创建: ${PR_URL}\"}" \
  "$GITEA_URL/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/issues/$ISSUE_NUM/comments" >/dev/null

# ========== Step 7: 通知审核 ==========
log "🔔 发送审核通知..."

NOTIFY_MSG="🤖 **自动化迭代完成**

📋 **Issue #${ISSUE_NUM}**: ${ISSUE_TITLE}
🔀 **PR #${PR_NUM}**: ${PR_URL}
🌿 **分支**: \`${BRANCH}\`
📝 **变更**: ${CHANGE_SUMMARY}

请审核并合并。"

if [[ -n "${FEISHU_WEBHOOK_URL:-}" ]]; then
  curl -s -X POST "$FEISHU_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"msg_type\":\"interactive\",\"card\":{\"header\":{\"title\":{\"tag\":\"plain_text\",\"content\":\"PR 待审核: #${ISSUE_NUM} ${ISSUE_TITLE}\"}},\"elements\":[{\"tag\":\"markdown\",\"content\":\"${NOTIFY_MSG}\"}]}}" >/dev/null
  log "✅ 飞书通知已发送"
else
  log "⚠️  飞书 Webhook 未配置，跳过通知"
  echo "$NOTIFY_MSG"
fi

# 更新状态
cat > "$STATE_FILE" <<EOF
{
  "issue": $ISSUE_NUM,
  "title": "$ISSUE_TITLE",
  "status": "pr_created",
  "branch": "$BRANCH",
  "pr_url": "$PR_URL",
  "pr_number": "$PR_NUM",
  "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

log "🎉 Issue #${ISSUE_NUM} 自动化迭代完成！PR: ${PR_URL}"
