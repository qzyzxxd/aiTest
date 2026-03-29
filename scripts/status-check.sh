#!/bin/bash

# DevOps Demo 状态检查脚本

echo "🔍 DevOps Demo 系统状态检查"
echo "================================"

cd /root/.picoclaw/workspace/projects/devops-demo

# 1. 容器状态
echo ""
echo "📦 容器状态:"
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"

# 2. 应用健康检查
echo ""
echo "❤️  应用健康检查:"
HEALTH=$(curl -s http://localhost:8080/health)
if [ $? -eq 0 ]; then
    echo "✅ 应用运行正常"
    echo "$HEALTH" | jq -r '.status' | head -1
else
    echo "❌ 应用无法访问"
fi

# 3. API 端点测试
echo ""
echo "📝 API 端点测试:"

echo "  测试主页..."
HOME=$(curl -s http://localhost:8080/)
if [ $? -eq 0 ]; then
    echo "  ✅ 主页正常"
else
    echo "  ❌ 主页失败"
fi

echo "  测试 API..."
API=$(curl -s http://localhost:8080/api/data)
if [ $? -eq 0 ]; then
    echo "  ✅ API 正常"
else
    echo "  ❌ API 失败"
fi

echo "  测试指标..."
METRICS=$(curl -s http://localhost:8080/metrics | head -1)
if [ $? -eq 0 ]; then
    echo "  ✅ 指标正常"
else
    echo "  ❌ 指标失败"
fi

# 4. 服务可用性
echo ""
echo "🌐 服务可用性:"

echo "  应用 (8080)..."
if curl -s --connect-timeout 2 http://localhost:8080/ > /dev/null; then
    echo "  ✅ 可用"
else
    echo "  ❌ 不可用"
fi

echo "  Grafana (3000)..."
if curl -s --connect-timeout 2 http://localhost:3000/ > /dev/null; then
    echo "  ✅ 可用"
else
    echo "  ❌ 不可用"
fi

echo "  Prometheus (9090)..."
if curl -s --connect-timeout 2 http://localhost:9090/ > /dev/null; then
    echo "  ✅ 可用"
else
    echo "  ❌ 不可用"
fi

# 5. 最近演示日志
echo ""
echo "📊 最近的演示记录:"
if [ -f logs/issue_*.json ]; then
    LATEST_LOG=$(ls -t logs/issue_*.json | head -1)
    echo "  最新日志: $(basename $LATEST_LOG)"
    echo "  创建时间: $(stat -c %y $LATEST_LOG | cut -d'.' -f1)"
else
    echo "  ❌ 没有找到演示日志"
fi

# 6. 资源使用情况
echo ""
echo "💻 资源使用情况:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" devops-demo-app devops-demo-grafana devops-demo-prometheus

echo ""
echo "================================"
echo "✅ 状态检查完成"