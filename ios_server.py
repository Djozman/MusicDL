#!/usr/bin/env python3
"""Thin iOS bridge with auth, rate limiting, and real-time track progress."""

import argparse
import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import glob
from collections import defaultdict

REPO = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
HOST = "0.0.0.0"
PORT = 8080

LOCK = threading.Lock()
SESSIONS = {}

RATE_LOCK = threading.Lock()
FAILED_ATTEMPTS = defaultdict(list)
MAX_ATTEMPTS = 5
BLOCK_DURATION = 300

def _is_blocked(ip):
    now = time.time()
    with RATE_LOCK:
        attempts = FAILED_ATTEMPTS.get(ip, [])
        attempts = [t for t in attempts if now - t < BLOCK_DURATION]
        FAILED_ATTEMPTS[ip] = attempts
        return len(attempts) >= MAX_ATTEMPTS

def _record_failed_auth(ip):
    now = time.time()
    with RATE_LOCK:
        attempts = FAILED_ATTEMPTS.get(ip, [])
        attempts = [t for t in attempts if now - t < BLOCK_DURATION]
        attempts.append(now)
        FAILED_ATTEMPTS[ip] = attempts

def _clear_failed_auth(ip):
    with RATE_LOCK:
        FAILED_ATTEMPTS.pop(ip, None)

def _check_auth(handler):
    client_ip = handler.client_address[0]
    token = os.environ.get("IOS_SERVER_TOKEN", "")
    if not token:
        return True
    if _is_blocked(client_ip):
        handler._send_json(429, {"error": "Too many failed attempts. Try again later."})
        return False
    if handler.headers.get("x-auth-token", "") != token:
        _record_failed_auth(client_ip)
        handler._send_json(401, {"error": "unauthorized"})
        return False
    _clear_failed_auth(client_ip)
    return True

def handle_preview(body):
    url = (body or {}).get("url", "").strip()
    if not url:
        return 400, {"type": "error", "message": "No URL provided"}
    e = dict(os.environ)
    e["PYTHONPATH"] = REPO
    p = subprocess.run([PY, "preview.py", url], cwd=REPO, env=e, capture_output=True, text=True, timeout=120)
    for line in p.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            return 200, json.loads(line)
        except Exception:
            continue
    return 502, {"type": "error", "message": f"Backend produced no JSON (exit {p.returncode})"}

def handle_download(body):
    url = (body or {}).get("url", "").strip()
    if not url:
        return 400, {"type": "error", "message": "No URL provided"}
    sid = os.urandom(8).hex()
    dl_dir = os.path.join(tempfile.gettempdir(), "ios_musicdl", sid)
    os.makedirs(dl_dir, exist_ok=True)
    with LOCK:
        SESSIONS[sid] = {
            "dir": dl_dir, "status": "pending", "files": [],
            "track_progress": [], "completed_tracks": 0,
            "error": None, "base_url": f"/files/{sid}/",
        }

    def _do_download():
        try:
            e = dict(os.environ)
            e["PYTHONPATH"] = REPO
            proc = subprocess.Popen(
                [PY, "download.py", url, "--out", dl_dir],
                cwd=REPO, env=e, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            for line in proc.stdout:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except Exception:
                    continue
                name = ev.get("name", "")
                etype = ev.get("type", "")
                payload = ev.get("payload", {}) or {}
                with LOCK:
                    if name == "track_started":
                        SESSIONS[sid]["track_progress"].append({
                            "title": payload.get("track", ""),
                            "artist": payload.get("artist", ""),
                            "index": payload.get("track_index"),
                            "total": payload.get("track_total"),
                            "status": "downloading",
                        })
                    elif name == "track_completed":
                        if SESSIONS[sid]["track_progress"]:
                            SESSIONS[sid]["track_progress"][-1]["status"] = "completed"
                        SESSIONS[sid]["completed_tracks"] += 1
                    elif etype == "error":
                        SESSIONS[sid]["error"] = ev.get("message", "Download failed")
            proc.wait()
            code = proc.returncode
            
            # Recursively find all audio files in the download directory
            audio_exts = {".flac", ".mp3", ".m4a", ".aac", ".wav", ".opus"}
            all_files = []
            for root, _, fnames in os.walk(dl_dir):
                for fname in fnames:
                    if not fname.startswith(".") and os.path.splitext(fname)[1].lower() in audio_exts:
                        rel_path = os.path.relpath(os.path.join(root, fname), dl_dir)
                        all_files.append(rel_path)
            files = sorted(all_files)

            with LOCK:
                SESSIONS[sid]["files"] = files
                if code == 0 and files:
                    SESSIONS[sid]["status"] = "done"
                else:
                    SESSIONS[sid]["status"] = "error"
                    if not SESSIONS[sid].get("error"):
                        SESSIONS[sid]["error"] = f"Download failed (exit {code})"
        except Exception as ex:
            with LOCK:
                SESSIONS[sid]["status"] = "error"
                SESSIONS[sid]["error"] = str(ex)

    threading.Thread(target=_do_download, daemon=True).start()
    return 200, {"type": "download_started", "session": sid, "status": "pending"}

def handle_status(sid):
    with LOCK:
        s = SESSIONS.get(sid)
        if not s:
            return 404, {"type": "error", "message": "Unknown session"}
        return 200, {
            "type": "status", "session": sid, "status": s["status"],
            "files": s["files"], "base_url": s["base_url"],
            "track_progress": list(s["track_progress"]),
            "completed_tracks": s["completed_tracks"],
            "message": s.get("error"),
        }

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send_json(self, status, obj):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_file(self, path):
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError:
            self.send_error(404, "Not found")
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Content-Disposition", f'attachment; filename="{os.path.basename(path)}"')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if not _check_auth(self):
            return
        if parsed.path == "/health":
            self._send_json(200, {"ok": True})
            return
        if parsed.path.startswith("/status/"):
            sid = parsed.path[len("/status/"):]
            status, obj = handle_status(sid)
            self._send_json(status, obj)
            return
        if parsed.path.startswith("/files/"):
            rel = urllib.parse.unquote(parsed.path[len("/files/"):])
            sid, _, name = rel.partition("/")
            with LOCK:
                base = SESSIONS.get(sid, {}).get("dir")
            if not base or not name:
                self.send_error(404)
                return
            # Prevent directory traversal, but allow subdirectories
            full = os.path.normpath(os.path.join(base, name))
            if not full.startswith(os.path.normpath(base)):
                self.send_error(404)
                return
            if not os.path.isfile(full):
                self.send_error(404)
                return
            self._send_file(full)
            return
        self.send_error(404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if not _check_auth(self):
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            body = json.loads(raw or b"{}")
        except Exception:
            body = {}
        if parsed.path == "/preview":
            status, obj = handle_preview(body)
        elif parsed.path == "/download":
            status, obj = handle_download(body)
        else:
            self._send_json(404, {"error": "not found"})
            return
        self._send_json(status, obj)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default=HOST)
    ap.add_argument("--port", type=int, default=PORT)
    args = ap.parse_args()
    server = http.server.ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Listening on 0.0.0.0:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
