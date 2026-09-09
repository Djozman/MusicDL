#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT/.remote"
SERVER_PORT="${SERVER_PORT:-8080}"
CLOUDFLARED="${CLOUDFLARED:-/opt/homebrew/bin/cloudflared}"
export HOME="$(echo ~)"
mkdir -p "$LOG_DIR"

# Load secrets from .env if present
if [[ -f "$ROOT/.env" ]]; then
  set -a
  source "$ROOT/.env"
  set +a
fi

if ! lsof -nP -iTCP:"$SERVER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  pkill -f "python3 $ROOT/ios_server.py" 2>/dev/null || true
  nohup "$ROOT/.venv/bin/python3" "$ROOT/ios_server.py" --port "$SERVER_PORT" >"$LOG_DIR/server.log" 2>&1 &
  for _ in $(seq 1 10); do lsof -nP -iTCP:"$SERVER_PORT" -sTCP:LISTEN >/dev/null 2>&1 && break; sleep 1; done
fi

if ! lsof -nP -iTCP:"$SERVER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Server not listening on :$SERVER_PORT" >&2
  exit 1
fi

: >"$LOG_DIR/tunnel.log"
(
  while :; do
    U="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/tunnel.log" 2>/dev/null | tail -n1 || true)"
    [[ -n "$U" ]] && echo "$U" > "$LOG_DIR/current_url.txt"
    sleep 2
  done
) &
WATCHER_PID=$!

"$CLOUDFLARED" tunnel --url "http://127.0.0.1:$SERVER_PORT" --no-autoupdate >"$LOG_DIR/tunnel.log" 2>&1
kill "$WATCHER_PID" 2>/dev/null || true
exit 0
