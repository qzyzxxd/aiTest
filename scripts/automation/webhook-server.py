#!/usr/bin/env python3
"""
webhook-server.py - Gitea Webhook 接收器
接收 Gitea Issue 事件，触发 Agent 自动化迭代

用法:
    python3 webhook-server.py start     # 前台启动
    python3 webhook-server.py daemon    # 后台守护进程
    python3 webhook-server.py stop      # 停止
    python3 webhook-server.py status    # 查看状态
    python3 webhook-server.py restart   # 重启
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
    if not signature.startswith("sha256="):
        return False
    expected = hmac.new(SECRET.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature[7:])


def log_event(msg: str):
    """记录事件到日志文件"""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    line = f"[{ts}] {msg}"
    print(line)
    (LOG_DIR / "webhook.log").open("a").write(line + "\n")


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
        if self.path != "/webhook/gitea":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(content_length)
        signature = self.headers.get("X-Gitea-Signature", "")
        event_type = self.headers.get("X-Gitea-Event", "")

        # 签名验证
        if SECRET and not verify_signature(payload, signature):
            log_event("⚠️ 签名验证失败")
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"Invalid signature")
            return

        # 解析 JSON
        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Invalid JSON")
            return

        log_event(f"📨 事件: {event_type}")

        # ─── Issue 事件：新开或重新打开时触发 Agent ───
        if event_type in ("issues", "issue"):
            action = data.get("action", "")
            issue = data.get("issue", {})
            issue_num = issue.get("number")
            labels = [l["name"] for l in issue.get("labels", [])]

            if action in ("opened", "reopened"):
                log_event(f"📋 Issue #{issue_num} 已创建: {issue.get('title')}")
                log_event(f"   标签: {', '.join(labels) if labels else '无'}")
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"OK - Agent triggered")
                trigger_agent(issue_num, action)
                return

        # ─── PR 事件：记录日志 ───
        elif event_type in ("pull_request",):
            action = data.get("action", "")
            pr = data.get("pull_request", {})
            pr_num = pr.get("number")
            log_event(f"🔀 PR #{pr_num}: {action}")

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "ok",
                "project": PROJECT_DIR,
                "secret_configured": bool(SECRET),
                "executor": EXECUTOR
            }).encode())
        elif self.path == "/status":
            # 返回所有 Issue 处理状态
            state_dir = Path(PROJECT_DIR) / "state" / "automation"
            states = {}
            for f in sorted(state_dir.glob("issue-*.json")):
                try:
                    states[f.stem] = json.loads(f.read_text())
                except Exception:
                    pass
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps(states, indent=2, ensure_ascii=False).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        """静音默认 access log"""
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
            print(f"   地址: http://{host}:{port}/webhook/gitea")
            print(f"   健康: http://{host}:{port}/health")
            print(f"   状态: http://{host}:{port}/status")
            return
        os.setsid()
        pid2 = os.fork()
        if pid2 > 0:
            sys.exit(0)

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
        print("⚠️  未找到 PID 文件，服务可能未运行")
        return
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, signal.SIGTERM)
        PID_FILE.unlink(missing_ok=True)
        print(f"✅ 服务已停止 (PID={pid})")
    except ProcessLookupError:
        PID_FILE.unlink(missing_ok=True)
        print("⚠️  进程不存在，已清理 PID 文件")
    except ValueError:
        PID_FILE.unlink(missing_ok=True)
        print("⚠️  PID 文件内容无效，已清理")


def show_status():
    """显示服务状态"""
    if not PID_FILE.exists():
        print("❌ 服务未运行")
        return
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)
        host = config.get("WEBHOOK_HOST", "0.0.0.0")
        port = config.get("WEBHOOK_PORT", "9876")
        print(f"✅ 服务运行中 PID={pid}")
        print(f"   地址: http://{host}:{port}/webhook/gitea")
        print(f"   健康: curl http://{host}:{port}/health")
        print(f"   状态: curl http://{host}:{port}/status")
    except ProcessLookupError:
        print("❌ 服务已停止（PID 文件残留）")
        PID_FILE.unlink(missing_ok=True)
    except ValueError:
        print("❌ PID 文件内容无效")
        PID_FILE.unlink(missing_ok=True)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "start"
    actions = {
        "start": lambda: start(daemon=False),
        "daemon": lambda: start(daemon=True),
        "stop": stop,
        "status": show_status,
        "restart": lambda: (stop(), start(daemon=True)),
    }
    if cmd in actions:
        actions[cmd]()
    else:
        print(f"用法: {sys.argv[0]} {{start|daemon|stop|status|restart}}")
        sys.exit(1)
