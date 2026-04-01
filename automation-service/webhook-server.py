#!/usr/bin/env python3
"""
webhook-server.py - Gitea/GitHub Webhook 接收器
接收 Issue 事件，触发 Agent 自动化迭代
"""
import http.server
import json
import os
import subprocess
import sys
import hmac
import hashlib
import signal
from pathlib import Path
from datetime import datetime, timezone

# ─── 配置加载 ───────────────────────────────────────────────
CONFIG_FILE = Path(__file__).parent / "config.env"
config = {}
if CONFIG_FILE.exists():
    for line in CONFIG_FILE.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()

SECRET = config.get("WEBHOOK_SECRET", "")
PROJECT_DIR = config.get("AGENT_WORK_DIR", str(Path(__file__).parent.parent.parent))
EXECUTOR = str(Path(__file__).parent / "agent-executor.sh")
PID_FILE = Path(PROJECT_DIR) / "state" / "automation" / "webhook.pid"
LOG_DIR = Path(PROJECT_DIR) / "logs" / "automation"

# 确保目录存在
for d in [LOG_DIR, Path(PROJECT_DIR) / "state" / "automation"]:
    d.mkdir(parents=True, exist_ok=True)


def verify_signature(payload: bytes, signature: str) -> bool:
    """验证 Webhook HMAC-SHA256 签名"""
    if not SECRET:
        return True
    if not signature:
        return False
    # 处理 GitHub 的 sha256= 前缀
    sig_to_check = signature[7:] if signature.startswith("sha256=") else signature
    expected = hmac.new(SECRET.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig_to_check)


def log_event(msg: str):
    """记录事件到日志文件"""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    line = f"[{ts}] {msg}"
    print(line)
    with (LOG_DIR / "webhook.log").open("a") as f:
        f.write(line + "\n")


def trigger_agent(issue_num: int, action: str = "opened"):
    """异步触发 Agent 执行器处理 Issue"""
    try:
        cmd = ["bash", EXECUTOR, "--issue", str(issue_num), "--action", action]
        log_path = LOG_DIR / f"agent-issue-{issue_num}.log"
        log_file = open(str(log_path), "a")
        proc = subprocess.Popen(
            cmd, stdout=log_file, stderr=subprocess.STDOUT,
            cwd=PROJECT_DIR, start_new_session=True
        )
        log_event(f"🤖 Agent 进程已启动 PID={proc.pid}, 处理 Issue #{issue_num}")
    except Exception as e:
        log_event(f"❌ 启动 Agent 失败: {e}")


# ─── HTTP 请求处理器 ────────────────────────────────────────
class WebhookHandler(http.server.BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        payload = self.rfile.read(content_length)
        
        # 兼容 Gitea 和 GitHub 的 Header
        signature = self.headers.get('X-Gitea-Signature') or self.headers.get('X-Hub-Signature-256', '')
        event_type = self.headers.get('X-Gitea-Event') or self.headers.get('X-GitHub-Event', '')
        delivery_id = self.headers.get('X-GitHub-Delivery') or 'N/A'

        # 签名验证
        if SECRET and not verify_signature(payload, signature):
            log_event(f"⚠️ 签名验证失败 (Delivery: {delivery_id})")
            # self.send_response(401)
            # self.end_headers()
            # return

        # 解析 JSON
        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        log_event(f"📨 事件: {event_type} (Delivery: {delivery_id})")

        # ─── Issue 事件 ───
        if event_type in ("issues", "issue"):
            action = data.get("action", "")
            issue = data.get("issue", {})
            issue_num = issue.get("number")
            
            if action in ("opened", "reopened"):
                log_event(f"📋 Issue #{issue_num} ({action}): {issue.get('title')}")
                self.send_response(202)
                self.end_headers()
                self.wfile.write(b"Accepted")
                trigger_agent(issue_num, action)
                return

        # ─── PR 事件 ───
        elif event_type in ("pull_request",):
            action = data.get("action", "")
            pr = data.get("pull_request", {})
            log_event(f"🔀 PR #{pr.get('number')} ({action})")

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "project": PROJECT_DIR}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


# ─── 服务管理 ───────────────────────────────────────────────
def start(daemon=False):
    """启动 Webhook 服务"""
    host = config.get("WEBHOOK_HOST", "0.0.0.0")
    port = int(config.get("WEBHOOK_PORT", "9876"))

    if daemon:
        pid = os.fork()
        if pid > 0:
            PID_FILE.write_text(str(pid))
            print(f"✅ Webhook 服务已后台启动 PID={pid}")
            sys.exit(0) # 父进程退出
        os.setsid()
        pid2 = os.fork()
        if pid2 > 0:
            sys.exit(0)

    # 关键修复：允许端口重用
    http.server.HTTPServer.allow_reuse_address = True
    server = http.server.HTTPServer((host, port), WebhookHandler)
    
    PID_FILE.write_text(str(os.getpid()))
    log_event(f"🚀 Webhook 服务已启动: http://{host}:{port}/webhook/gitea")

    def shutdown(signum, frame):
        log_event("👋 服务已停止")
        PID_FILE.unlink(missing_ok=True)
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)
    server.serve_forever()


def stop():
    """停止 Webhook 服务"""
    if not PID_FILE.exists():
        print("⚠️  未找到 PID 文件")
        return
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, signal.SIGTERM)
        PID_FILE.unlink(missing_ok=True)
        print(f"✅ 服务已停止 (PID={pid})")
    except Exception as e:
        PID_FILE.unlink(missing_ok=True)
        print(f"⚠️  停止失败: {e}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "start"
    if cmd == "start":
        start(daemon=False)
    elif cmd == "daemon":
        start(daemon=True)
    elif cmd == "stop":
        stop()
    elif cmd == "restart":
        stop()
        start(daemon=True)
    else:
        print(f"用法: {sys.argv[0]} {{start|daemon|stop|restart}}")
