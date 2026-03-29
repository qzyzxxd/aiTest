#!/bin/bash

# DevOps 自动化流程演示
# 一键运行：需求 → 开发 → PR → 审查 → 合并 → 测试 → 发布 → 监控

set -e

# 配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_DIR/app"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$PROJECT_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_section() {
    echo ""
    echo -e "${PURPLE}=== $1 ===${NC}"
    echo ""
}

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

# 创建日志目录
mkdir -p "$LOG_DIR"

# 流程步骤
step_1_requirement() {
    log_section "步骤 1: 需求整理"
    
    log_info "模拟用户提交需求..."
    
    # 模拟创建 Issue
    cat > "$LOG_DIR/issue_${TIMESTAMP}.json" << EOF
{
  "issue_number": 1,
  "title": "添加用户认证功能",
  "body": "需要添加基本的用户登录和注册功能，支持邮箱和密码认证。",
  "labels": ["type::feature", "priority::high", "scope::backend"]
}
EOF
    
    log_info "✓ 需求已记录: issue_1"
    log_info "  - 类型: 功能开发"
    log_info "  - 优先级: 高"
    log_info "  - 范围: 后端"
    
    sleep 1
}

step_2_development() {
    log_section "步骤 2: 开发"
    
    log_info "创建开发分支..."
    log_info "✓ 分支创建: feature/issue-1-user-authentication"
    
    log_info "开发功能..."
    log_info "✓ 用户认证模块开发完成"
    log_info "✓ 单元测试编写完成"
    log_info "✓ API 文档更新完成"
    
    sleep 1
}

step_3_pr_creation() {
    log_section "步骤 3: 创建 PR"
    
    log_info "提交代码..."
    log_info "✓ 代码已提交到 feature/issue-1-user-authentication"
    
    log_info "推送代码..."
    log_info "✓ 代码已推送到远程仓库"
    
    log_info "创建 Pull Request..."
    log_info "✓ PR #42 创建成功"
    log_info "  - 标题: feat: 添加用户认证功能"
    log_info "  - 目标分支: main"
    log_info "  - 关联 Issue: #1"
    
    sleep 1
}

step_4_review() {
    log_section "步骤 4: 代码审查"
    
    log_info "自动化审查..."
    log_info "✓ 代码质量检查通过"
    log_info "✓ 安全扫描通过"
    log_info "✓ 单元测试通过 (100% 覆盖率)"
    
    log_info "人工审查..."
    log_info "✓ 代码审查通过"
    log_info "✓ 功能测试通过"
    log_info "✓ 文档审查通过"
    
    log_info "添加审查评论..."
    log_info "✓ LGTM (Looks Good To Me)"
    
    sleep 1
}

step_5_merge() {
    log_section "步骤 5: 合并代码"
    
    log_info "满足合并条件..."
    log_info "✓ 至少 1 个审查通过"
    log_info "✓ 所有 CI 检查通过"
    log_info "✓ 冲突已解决"
    
    log_info "合并 PR..."
    log_info "✓ PR #42 已合并到 main"
    log_info "✓ 分支 feature/issue-1-user-authentication 已删除"
    
    sleep 1
}

step_6_build_test() {
    log_section "步骤 6: 构建和测试"
    
    log_info "触发 CI/CD 流水线..."
    
    log_info "构建应用..."
    log_info "✓ Docker 镜像构建成功"
    log_info "  - 镜像: devops-demo:1.0.1"
    
    log_info "运行测试..."
    log_info "✓ 单元测试通过"
    log_info "✓ 集成测试通过"
    log_info "✓ 端到端测试通过"
    
    log_info "✓ 测试覆盖率: 95%"
    
    sleep 1
}

step_7_deploy() {
    log_section "步骤 7: 部署"
    
    log_info "部署到开发环境..."
    log_info "✓ 开发环境部署成功"
    log_info "  - URL: https://dev.smalldong.top"
    
    log_info "健康检查..."
    log_info "✓ 应用健康状态: OK"
    log_info "✓ API 响应时间: <100ms"
    
    log_info "部署到生产环境..."
    log_info "✓ 生产环境部署成功"
    log_info "  - URL: https://smalldong.top"
    
    log_info "蓝绿部署验证..."
    log_info "✓ 流量切换成功"
    log_info "✓ 回滚测试通过"
    
    sleep 1
}

step_8_monitoring() {
    log_section "步骤 8: 监控和反馈"
    
    log_info "监控指标收集..."
    log_info "✓ 请求量: 1,234 req/s"
    log_info "✓ 响应时间: 45ms (P99: 120ms)"
    log_info "✓ 错误率: 0.01%"
    log_info "✓ CPU 使用率: 45%"
    log_info "✓ 内存使用率: 60%"
    
    log_info "日志分析..."
    log_info "✓ 没有发现错误日志"
    log_info "✓ 没有异常告警"
    
    log_info "用户体验监控..."
    log_info "✓ 满意度评分: 4.8/5.0"
    log_info "✓ 投诉数量: 0"
    
    sleep 1
}

step_9_feedback_loop() {
    log_section "步骤 9: 反馈循环"
    
    log_info "分析监控数据..."
    log_info "✓ 发现一个性能优化机会"
    log_info "  - 缓存命中率可以提升 15%"
    
    log_info "自动创建新的 Issue..."
    
    cat > "$LOG_DIR/issue_feedback_${TIMESTAMP}.json" << EOF
{
  "issue_number": 2,
  "title": "优化用户认证缓存性能",
  "body": "监控发现用户认证接口响应时间可以进一步优化，建议引入 Redis 缓存。",
  "labels": ["type::improvement", "priority::medium", "scope::backend"],
  "source": "monitoring_auto"
}
EOF
    
    log_info "✓ 新 Issue #2 已创建"
    log_info "  - 来源: 监控系统自动创建"
    log_info "  - 类型: 性能优化"
    
    log_info "触发新一轮需求整理..."
    log_info "✓ 返回步骤 1: 需求整理"
    
    sleep 1
}

# 启动应用
start_application() {
    log_section "启动应用环境"
    
    cd "$PROJECT_DIR"
    
    log_info "启动 Docker 服务..."
    docker-compose up -d
    
    log_info "等待服务启动..."
    sleep 5
    
    log_info "检查服务状态..."
    docker-compose ps
    
    log_info "✓ 应用环境启动成功"
    echo ""
    log_info "访问地址:"
    log_info "  - 应用: http://localhost:8080"
    log_info "  - Prometheus: http://localhost:9090"
    log_info "  - Grafana: http://localhost:3000 (admin/admin)"
}

# 停止应用
stop_application() {
    log_section "停止应用环境"
    
    cd "$PROJECT_DIR"
    
    log_info "停止 Docker 服务..."
    docker-compose down
    
    log_info "✓ 应用环境已停止"
}

# 显示帮助
show_help() {
    cat << EOF
DevOps 自动化流程演示工具

用法: $0 [选项]

选项:
  demo           运行完整的演示流程
  start          启动应用环境
  stop           停止应用环境
  status         查看应用状态
  logs           查看应用日志
  test           运行测试
  help           显示帮助信息

示例:
  $0 demo        运行完整演示
  $0 start       启动应用
  $0 stop        停止应用

流程说明:
  1. 需求整理     - 用户提交需求，系统自动分类
  2. 开发         - 基于需求创建分支，开发功能
  3. 创建 PR      - 提交代码，创建 Pull Request
  4. 代码审查     - 自动化 + 人工审查
  5. 合并         - 审查通过后合并代码
  6. 构建测试     - 构建 Docker 镜像，运行测试
  7. 部署         - 部署到生产环境
  8. 监控         - 监控应用性能和健康状态
  9. 反馈循环     - 发现问题自动创建新需求

EOF
}

# 主函数
main() {
    local command=${1:-"demo"}
    
    case "$command" in
        "demo")
            log_section "DevOps 自动化流程演示"
            log_info "开始运行完整的自动化流程演示..."
            log_info "日志目录: $LOG_DIR"
            
            step_1_requirement
            step_2_development
            step_3_pr_creation
            step_4_review
            step_5_merge
            step_6_build_test
            step_7_deploy
            step_8_monitoring
            step_9_feedback_loop
            
            log_section "演示完成"
            log_info "✓ 完整的 DevOps 自动化流程演示完成"
            log_info "✓ 需求 → 开发 → PR → 审查 → 合并 → 测试 → 发布 → 监控 → 反馈"
            log_info ""
            log_info "查看日志: cat $LOG_DIR/*.json"
            
            ;;
            
        "start")
            start_application
            ;;
            
        "stop")
            stop_application
            ;;
            
        "status")
            log_section "应用状态"
            cd "$PROJECT_DIR"
            docker-compose ps
            
            # 健康检查
            log_info "健康检查..."
            if curl -s http://localhost:8080/health > /dev/null; then
                log_info "✓ 应用健康检查通过"
            else
                log_warn "✗ 应用健康检查失败"
            fi
            
            if curl -s http://localhost:3000 > /dev/null; then
                log_info "✓ Grafana 访问正常"
            else
                log_warn "✗ Grafana 访问失败"
            fi
            
            if curl -s http://localhost:9090 > /dev/null; then
                log_info "✓ Prometheus 访问正常"
            else
                log_warn "✗ Prometheus 访问失败"
            fi
            ;;
            
        "logs")
            log_section "应用日志"
            cd "$PROJECT_DIR"
            docker-compose logs -f
            ;;
            
        "test")
            log_section "运行测试"
            cd "$APP_DIR"
            
            log_info "安装依赖..."
            npm install
            
            log_info "运行测试..."
            npm test
            
            log_info "✓ 测试完成"
            ;;
            
        "help"|"-h"|"--help")
            show_help
            ;;
            
        *)
            log_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"