# Finding 09 — Information disclosure via HTTP headers and robots.txt

**Target:** http://localhost:4942
**Severity:** Low
**Status:** Confirmed (reproduced on every response)
**Flag:** none

## Summary

Every response leaks internal information through custom headers, and
`robots.txt` enumerates the sensitive routes the app tries to hide.

Captured response headers:

```
x-pocketbase: http://localhost:8090          # exact address of the DB admin API
x-42-internal: campus=paris                  # internal metadata
x-powered-by: Python/3.11 FastAPI/0.104
server: uvicorn/0.24.0 Linux
```

`robots.txt` disallows: `/admin`, `/staff`, `/internal`, `/backup`,
`/api/docs-internal` — effectively publishing a map of "protected" surfaces.

## How it works

The app is deployed with debug/internal middleware enabled (custom headers
are added unconditionally), and the developers relied on `robots.txt`
disallow rules as if they were an access-control mechanism.

## Impact

- Hands an attacker the exact internal service address (`localhost:8090`),
  technology stack and versions to target (known CVE lookup).
- robots.txt removes all reconnaissance guesswork about where hidden
  functionality lives.

## Avoidance

- Strip `x-42-internal` / `x-pocketbase` and generic `x-powered-by` headers
  in production; return a minimal `Server` header.
- Never use `robots.txt` as a substitute for authentication — the routes
  should be gated server-side (they are, but the listing still leaks their
  existence and exact paths).
