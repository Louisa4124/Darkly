# Breach: header-robots-info-disclosure

**Target:** http://localhost:4942
**Severity:** Low
**Flag:** none — this breach does not yield a flag

## How it works

The app is deployed with debug/internal middleware enabled, so **every**
response leaks internal information through custom headers, and `robots.txt`
enumerates the routes the developers intended to keep hidden:

Annotated example (the `#` comments are annotations, not part of the response):

```
x-pocketbase: http://localhost:8090          # exact address of the DB admin API
x-42-internal: campus=paris                  # internal metadata
x-powered-by: Python/3.11 FastAPI/0.104
server: uvicorn/0.24.0 Linux
```

`robots.txt` disallows: `/admin`, `/staff`, `/internal`, `/backup`,
`/api/docs-internal` — effectively publishing a map of the "protected"
surfaces. The developers relied on robots.txt as if it were access control.

## Steps to reproduce

Run `./exploit.sh [base_url]` (defaults to `http://localhost:4942`) — it captures
the response headers of the front page and
prints robots.txt. No authentication or special conditions: this information
is handed to every visitor on every request.

## Impact

- Hands an attacker the exact internal service address (`localhost:8090`) to
  target (this is how the PocketBase admin API in the takeover breach is found).
- Stack + versions (`FastAPI/0.104`, `uvicorn/0.24.0`, `Python/3.11`) enable
  direct known-CVE lookup.
- robots.txt removes all reconnaissance guesswork about where hidden
  functionality lives.

## How it could have been avoided

- Strip `x-42-internal` / `x-pocketbase` and generic `x-powered-by` headers
  in production; return a minimal `Server` header.
- Treat robots.txt purely as a crawler hint, never as access control — the
  routes are gated server-side, but the listing still leaks their existence
  and exact paths.
- Never let debug middleware run in production deployments.
