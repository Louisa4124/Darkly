# Breach: unrestricted-file-download

**Target:** http://localhost:4942 — `GET /projects/download?file=<name>`
**Severity:** Medium
**Flag:** none — this breach does not yield a flag

## How it works

The download endpoint resolves the `file` query parameter directly against
the application's assets directory with **no allowlist**. Any file whose name
is known (or guessable) inside that directory is served to any visitor:

```
GET /projects/download?file=staff_guide.pdf
-> "Staff onboarding guide — JWT config: see /internal/config (localhost only)"
```

That document openly points to the internal config endpoint — the exact
anchor used in the SSRF/relay breach to steal `/internal/config`.

Path traversal itself is hardened (tested `%2e%2e%2f`, `....//`,
`..%2f..%2fetc%2fpasswd`, and the absolute-path probe `/etc/passwd` — all
answered `forbidden` or `not found`), so the
weakness is not traversal but the **missing allowlist**: the endpoint accepts
any *named* file, and its responses act as an oracle distinguishing
existing-but-blocked files (`forbidden`) from missing ones (`not found`).

## Steps to reproduce

Run `./exploit.sh [base_url] [session_cookie_jar]`:

1. `GET /projects/download?file=staff_guide.pdf` → internal staff document
   returned to an unauthenticated visitor.
2. Traversal attempts → blocked (`forbidden` / `not found`).
3. The error wording differs between existing and missing files.

## Impact

- Arbitrary in-directory file disclosure to unauthenticated users.
- Internal documents (like the staff guide naming `/internal/config` and its
  JWT hints) materially advance the other breaches.
- The `not found` vs `forbidden` oracle helps map the served directory.

## How it could have been avoided

- Serve downloads from an explicit allowlist of asset IDs/names.
- Keep sensitive documents out of the web-servable directory entirely.
- Return one identical generic error for both missing and denied files.
