FROM python:3.10-slim

# 安装必要工具
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    jq \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制脚本
COPY webhook-server.py .
COPY agent-executor.sh .
COPY config.env .

# 确保脚本可执行
RUN chmod +x agent-executor.sh

# 暴露 Webhook 端口
EXPOSE 9876

# 启动服务
# 注意：在容器内我们直接运行 start (前台模式)，由 Docker 负责生命周期管理
CMD ["python3", "webhook-server.py", "start"]
