#!/usr/bin/env bash
#
# start_remote.sh — expose the local MusicDL server to the internet via a
# Cloudflare quick tunnel, so the iOS app can reach it from any network
# (even the phone's own hotspot / when the Mac is at home and you're outside).
#
# Cloudflare Tunnel makes an OUTBOUND connection from the Mac, so it works
# behind NAT, VPNs, and hotspots with no port-forwarding.
#
# Usage:
#   ./start_remote.sh            # start server + tunnel, print the public URL
#   ./start_remote.sh --path     # also copy the public URL to the clipboard
#
# NOTE: quick-tunnel URLs (trycloudflare.com) change on EVERY restart.
# For a permanent URL, use a named tunnel (needs a Cloudflare account + domain);
# see the comment at the bottom.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_PY="$ROOT/ios_server.py"
SERVER_PORT="${SERVER_PORT:-8080}"
LOG_DIR="$ROOT/.remote"

mkdir -p "$LOG_DIR"

# ── Start the Python bridge if it isn't already running ────────────────────
if lsof -nP -iTCP:"$SERVER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "▸ ios_server already listening on :$SERVER_PORT — reusing it."
else
  echo "▸ Starting ios_server.py on :$SERVER_PORT …"
  nohup python3 "$SERVER_PY" --port "$SERVER_PORT" >"$LOG_DIR/server.log" 2>&1 &
  sleep 1
fi

# ── Start Cloudflare quick tunnel to expose localhost:$SERVER_PORT ─────────
echo "▸ Starting Cloudflare quick tunnel…"
pkill -f "cloudflared tunnel --url" 2>/dev/null || true
# Cloudflare prints the public URL to stderr; stream it to a file so we can
# read back the URL after a reboot. cloudflared stays in the foreground so
# launchd (KeepAlive) restarts it if it dies.
nohup cloudflared tunnel --url "http://127.0.0.1:$SERVER_PORT" \
   --no-autoupdate >"$LOG_DIR/tunnel.log" 2>&1 &
TUNNEL_PID=$!

# Cloudflare prints the public URL to the log; wait for it.
URL=""
for _ in $(seq 1 30); do
  URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/tunnel.log" | head -n1 || true)"
  [[ -n "$URL" ]] && break
  sleep 1
done

if [[ -z "$URL" ]]; then
  echo "✗ Timed out waiting for the tunnel URL. See $LOG_DIR/tunnel.log" >&2
  exit 1
fi

# Cloudflare prints the public URL to the log; wait for it.
URL=""
for _ in $(seq 1 30); do
  URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/tunnel.log" | head -n1 || true)"
  [[ -n "$URL" ]] && break
  sleep 1
done

if [[ -z "$URL" ]]; then
  echo "✗ Timed out waiting for the tunnel URL. See $LOG_DIR/tunnel.log" >&2
  exit 1
fi

echo "✓ Public URL: $URL"
echo "$URL" > "$LOG_DIR/current_url.txt"
if [[ "${1:-}" == "--path" || "${COPY_URL:-}" == "1" ]]; then
  echo -n "$URL" | pbcopy
  echo "  (copied to clipboard)"
fi
echo "  Set this URL in the iOS app, Server field. Works from any network."
echo "  URL also saved to: $LOG_DIR/current_url.txt"