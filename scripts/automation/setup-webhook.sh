#!/usr/bin/env bash
# setup-webhook.sh - 在 Gitea 仓库上配置 Webhook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env" 2>/dev/null || { echo "❌ config.env 未配置"; exit 1; }

WEBHOOK_URL="$GITEA_URL/api/v1/repos/$GITEA_OWNER/$GITEA_REPO/hooks"
PAYLOAD_URL="http://127.0.0.1:${WEBHOOK_PORT}/webhook/gitea"

echo "🔧 配置 Gitea Webhook..."
echo "   仓库: $GITEA_OWNER/$GITEA_REPO"
echo "   目标: $PAYLOAD_URL"

# 检查是否已存在 webhook
EXISTING=$(curl -s -H "Authorization: token $GITEA_API_TOKEN" "$WEBHOOK_URL" | \
  python3 -c "
import sys, json
hooks = json.load(sys.stdin)
for h in hooks:
    if h.get('config',{}).get('url') == '$PAYLOAD_URL':
        print(h['id'])
        break
" 2>/dev/null)

if [[ -n "$EXISTING" ]]; then
  echo "⚠️  Webhook 已存在 (ID: $EXISTING)，先删除..."
  curl -s -X DELETE -H "Authorization: token $GITEA_API_TOKEN" "$WEBHOOK_URL/$EXISTING" >/dev/null
fi

# 创建 Webhook
RESULT=$(curl -s -X POST \
  -H "Authorization: token $GITEA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"gitea\",
    \"config\": {
      \"url\": \"$PAYLOAD_URL\",
      \"content_type\": \"json\",
      \"secret\": \"${WEBHOOK_SECRET:-}\"
    },
    \"events\": [\"issues\", \"issue_comment\", \"pull_request\"],
    \"active\": true,
    \"branch_filter\": \"*\"
  }" \
  "$WEBHOOK_URL")

echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"

echo ""
echo "✅ Webhook 配置完成"
echo "   测试: curl -X POST $PAYLOAD_URL -H 'Content-Type: application/json' -d '{\"action\":\"opened\",\"issue\":{\"number\":1,\"title\":\"Test\"}}'"
