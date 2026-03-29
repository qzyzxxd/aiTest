#!/bin/bash

# Issue 自动分类脚本
# 根据 Issue 内容自动添加标签和分配

set -e

# 配置
GITEA_URL="https://gitea.smalldong.top"
REPO_OWNER="smalldong"
REPO_NAME="devops-demo"
TOKEN=$(cat ~/.gitea/token || echo "")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v jq &> /dev/null; then
        log_error "jq 未安装，请先安装: apt-get install jq"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装: apt-get install curl"
        exit 1
    fi
    
    if [ -z "$TOKEN" ]; then
        log_warn "未找到 Gitea token，将使用公开 API"
    fi
}

# 分析 Issue 内容
analyze_issue() {
    local issue_number=$1
    local issue_data=$2
    
    local title=$(echo "$issue_data" | jq -r '.title')
    local body=$(echo "$issue_data" | jq -r '.body')
    local labels=$(echo "$issue_data" | jq -r '.labels[]?.name' 2>/dev/null || echo "")
    
    log_info "分析 Issue #$issue_number: $title"
    
    # 关键词分析
    local new_labels=()
    
    # 类型分类
    if echo "$title$body" | grep -qiE "(bug|fix|error|crash|broken)"; then
        new_labels+=("type::bug")
    elif echo "$title$body" | grep -qiE "(feature|enhancement|add|implement|new)"; then
        new_labels+=("type::feature")
    elif echo "$title$body" | grep -qiE "(improve|refactor|optimize|better)"; then
        new_labels+=("type::improvement")
    elif echo "$title$body" | grep -qiE "(document|doc|readme|guide)"; then
        new_labels+=("type::documentation")
    else
        new_labels+=("type::task")
    fi
    
    # 优先级分析
    if echo "$title$body" | grep -qiE "(urgent|critical|asap|emergency)"; then
        new_labels+=("priority::critical")
    elif echo "$title$body" | grep -qiE "(important|soon|high)"; then
        new_labels+=("priority::high")
    elif echo "$title$body" | grep -qiE "(low|nice to have|maybe)"; then
        new_labels+=("priority::low")
    else
        new_labels+=("priority::medium")
    fi
    
    # 范围分析
    if echo "$title$body" | grep -qiE "(frontend|ui|interface|user interface)"; then
        new_labels+=("scope::frontend")
    elif echo "$title$body" | grep -qiE "(backend|api|server|database)"; then
        new_labels+=("scope::backend")
    elif echo "$title$body" | grep -qiE "(test|testing|qa)"; then
        new_labels+=("scope::testing")
    elif echo "$title$body" | grep -qiE "(deploy|deployment|ci/cd|pipeline)"; then
        new_labels+=("scope::devops")
    fi
    
    # 状态标签
    new_labels+=("triage")
    new_labels+=("needs-review")
    
    # 去重
    local unique_labels=$(printf "%s\n" "${new_labels[@]}" | sort -u | tr '\n' ' ')
    
    echo "$unique_labels"
}

# 更新 Issue 标签
update_issue_labels() {
    local issue_number=$1
    local labels=$2
    
    if [ -z "$TOKEN" ]; then
        log_warn "未配置 token，无法更新标签"
        log_info "建议添加标签: $labels"
        return
    fi
    
    log_info "更新 Issue #$issue_number 标签..."
    
    local label_array=$(echo "$labels" | sed 's/ /","/g' | sed 's/^/"/' | sed 's/$/"/')
    
    curl -X PUT \
        -H "Authorization: token $TOKEN" \
        -H "Content-Type: application/json" \
        "$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/issues/$issue_number/labels" \
        -d "{\"labels\": [$label_array]}" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_info "标签更新成功"
    else
        log_error "标签更新失败"
    fi}

# 添加评论
add_comment() {
    local issue_number=$1
    local comment=$2
    
    if [ -z "$TOKEN" ]; then
        log_warn "未配置 token，无法添加评论"
        return
    fi
    
    log_info "添加评论到 Issue #$issue_number..."
    
    curl -X POST \
        -H "Authorization: token $TOKEN" \
        -H "Content-Type: application/json" \
        "$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/issues/$issue_number/comments" \
        -d "{\"body\": \"$comment\"}" \
        2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_info "评论添加成功"
    else
        log_error "评论添加失败"
    fi
}

# 生成实现建议
generate_suggestion() {
    local title=$1
    local body=$2
    
    local suggestion="## 🤖 AI 分析建议\n\n"
    suggestion+="### 类型识别\n"
    suggestion+="根据关键词分析，这个 Issue 被分类为：\n\n"
    suggestion+="- 类型：根据标题和内容自动识别\n"
    suggestion+="- 优先级：根据紧急程度关键词判断\n"
    suggestion+="- 范围：根据技术栈关键词确定\n\n"
    suggestion+="### 实现建议\n"
    suggestion+="1. **需求确认**：与团队确认具体需求和验收标准\n"
    suggestion+="2. **技术评估**：评估技术复杂度和依赖关系\n"
    suggestion+="3. **任务分解**：将大任务分解为小的可执行任务\n"
    suggestion+="4. **测试计划**：制定详细的测试计划\n\n"
    suggestion+="### 风险提示\n"
    suggestion+="- 请确认是否有相关的技术债务需要同时处理\n"
    suggestion+="- 评估此变更对现有功能的影响\n"
    suggestion+="- 确认是否需要文档更新\n\n"
    suggestion+="---\n\n"
    suggestion+="*此评论由自动化系统生成，请人工审核确认。*"
    
    echo "$suggestion"
}

# 主函数
main() {
    local issue_number=$1
    
    if [ -z "$issue_number" ]; then
        log_error "请提供 Issue 编号"
        echo "用法: $0 <issue_number>"
        exit 1
    fi
    
    check_dependencies
    
    log_info "开始处理 Issue #$issue_number..."
    
    # 获取 Issue 数据
    local issue_url="$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/issues/$issue_number"
    local issue_data=$(curl -s "$issue_url")
    
    if [ -z "$issue_data" ]; then
        log_error "无法获取 Issue #$issue_number 的数据"
        exit 1
    fi
    
    # 分析 Issue
    local labels=$(analyze_issue "$issue_number" "$issue_data")
    local title=$(echo "$issue_data" | jq -r '.title')
    local body=$(echo "$issue_data" | jq -r '.body')
    
    log_info "建议标签: $labels"
    
    # 更新标签
    update_issue_labels "$issue_number" "$labels"
    
    # 生成并添加建议
    local suggestion=$(generate_suggestion "$title" "$body")
    add_comment "$issue_number" "$suggestion"
    
    log_info "Issue #$issue_number 处理完成"
}

# 执行主函数
main "$@"