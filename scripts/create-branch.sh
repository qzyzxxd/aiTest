#!/bin/bash

# 分支管理脚本
# 根据 Issue 自动创建和切换分支

set -e

# 配置
GITEA_URL="https://gitea.smalldong.top"
REPO_OWNER="smalldong"
REPO_NAME="devops-demo"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查 Git 仓库
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        exit 1
    fi
    
    log_info "Git 仓库检查通过"
}

# 获取 Issue 信息
get_issue_info() {
    local issue_number=$1
    
    local issue_url="$GITEA_URL/api/v1/repos/$REPO_OWNER/$REPO_NAME/issues/$issue_number"
    local issue_data=$(curl -s "$issue_url")
    
    if [ -z "$issue_data" ]; then
        log_error "无法获取 Issue #$issue_number 的信息"
        exit 1
    fi
    
    echo "$issue_data"
}

# 生成分支名称
generate_branch_name() {
    local issue_number=$1
    local issue_title=$2
    
    # 清理标题：小写、替换空格和特殊字符为连字符
    local branch_name=$(echo "$issue_title" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9]/-/g' | \
        sed 's/-\+/-/g' | \
        sed 's/^-\|-$//g' | \
        cut -c1-50) # 限制长度
    
    # 组合 Issue 编号和标题
    local final_name="issue-$issue_number-$branch_name"
    
    echo "$final_name"
}

# 获取 Issue 类型
get_issue_type() {
    local issue_data=$1
    
    local labels=$(echo "$issue_data" | jq -r '.labels[]?.name' 2>/dev/null || echo "")
    
    if echo "$labels" | grep -q "type::feature"; then
        echo "feature"
    elif echo "$labels" | grep -q "type::bug"; then
        echo "bugfix"
    elif echo "$labels" | grep -q "type::documentation"; then
        echo "docs"
    else
        echo "chore"
    fi
}

# 创建分支
create_branch() {
    local issue_number=$1
    local branch_name=$2
    local base_branch=${3:-"main"}
    
    log_step "更新远程仓库信息..."
    git fetch origin
    
    log_step "创建新分支: $branch_name"
    
    # 检查分支是否已存在
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_warn "分支 $branch_name 已存在"
        read -p "是否切换到现有分支? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout "$branch_name"
            log_info "已切换到分支: $branch_name"
            return 0
        else
            log_error "操作已取消"
            exit 1
        fi
    fi
    
    # 创建并切换到新分支
    git checkout -b "$branch_name" "origin/$base_branch"
    
    if [ $? -eq 0 ]; then
        log_info "分支创建成功: $branch_name"
    else
        log_error "分支创建失败"
        exit 1
    fi
}

# 设置分支描述
set_branch_description() {
    local branch_name=$1
    local issue_title=$2
    local issue_number=$3
    
    local description="Issue #$issue_number: $issue_title"
    
    if command -v git config &> /dev/null; then
        git config branch."$branch_name".description "$description"
        log_info "设置分支描述: $description"
    fi
}

# 创建初始提交
create_initial_commit() {
    local issue_number=$1
    local branch_name=$2
    
    log_step "创建初始提交..."
    
    # 创建占位文件
    echo "# Issue #$issue_number" > "ISSUE-$issue_number.md"
    echo "" >> "ISSUE-$issue_number.md"
    echo "## Issue 相关" >> "ISSUE-$issue_number.md"
    echo "- Issue URL: $GITEA_URL/$REPO_OWNER/$REPO_NAME/issues/$issue_number" >> "ISSUE-$issue_number.md"
    echo "- Branch: $branch_name" >> "ISSUE-$issue_number.md"
    echo "" >> "ISSUE-$issue_number.md"
    echo "## 实现计划" >> "ISSUE-$issue_number.md"
    echo "- [ ] 分析需求" >> "ISSUE-$issue_number.md"
    echo "- [ ] 编写代码" >> "ISSUE-$issue_number.md"
    echo "- [ ] 编写测试" >> "ISSUE-$issue-number.md"
    echo "- [ ] 更新文档" >> "ISSUE-$issue_number.md"
    
    git add "ISSUE-$issue_number.md"
    git commit -m "feat(issue-$issue_number): Initialize development for Issue #$issue_number"
    
    log_info "初始提交创建成功"
}

# 显示后续步骤
show_next_steps() {
    local issue_number=$1
    local branch_name=$2
    
    echo ""
    log_info "下一步操作："
    echo ""
    echo "1. 开始开发："
    echo "   - 修改代码以解决 Issue #$issue_number"
    echo "   - 运行测试: npm test"
    echo ""
    echo "2. 提交代码："
    echo "   git add ."
    echo "   git commit -m 'feat(issue-$issue_number): 描述你的变更'"
    echo ""
    echo "3. 推送代码："
    echo "   git push -u origin $branch_name"
    echo ""
    echo "4. 创建 Pull Request："
    echo "   ./scripts/create-pr.sh $issue_number"
    echo ""
}

# 主函数
main() {
    local issue_number=$1
    local base_branch=${2:-"main"}
    
    if [ -z "$issue_number" ]; then
        log_error "请提供 Issue 编号"
        echo "用法: $0 <issue_number> [base_branch]"
        echo "示例: $0 123"
        echo "示例: $0 123 develop"
        exit 1
    fi
    
    log_info "开始为 Issue #$issue_number 创建开发分支..."
    
    # 检查环境
    check_git_repo
    
    # 获取 Issue 信息
    log_step "获取 Issue #$issue_number 信息..."
    local issue_data=$(get_issue_info "$issue_number")
    local issue_title=$(echo "$issue_data" | jq -r '.title')
    local issue_state=$(echo "$issue_data" | jq -r '.state')
    
    if [ "$issue_state" != "open" ]; then
        log_warn "Issue #$issue_number 不是开放状态，状态: $issue_state"
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_info "Issue 标题: $issue_title"
    
    # 生成分支名称
    local branch_name=$(generate_branch_name "$issue_number" "$issue_title")
    log_info "分支名称: $branch_name"
    
    # 创建分支
    create_branch "$issue_number" "$branch_name" "$base_branch"
    
    # 设置分支描述
    set_branch_description "$branch_name" "$issue_title" "$issue_number"
    
    # 创建初始提交
    create_initial_commit "$issue_number" "$branch_name"
    
    # 显示后续步骤
    show_next_steps "$issue_number" "$branch_name"
    
    log_info "开发分支创建完成！"
}

# 执行主函数
main "$@"