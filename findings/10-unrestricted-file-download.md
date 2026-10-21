# Finding 10 — Unrestricted arbitrary file download (no allowlist)

**Target:** http://localhost:4942/projects/download?file=...
**Severity:** Medium
**Status:** Confirmed (arbitrary in-directory file served; traversal itself blocked)
**Flag:** none

## Summary

The download endpoint resolves the `file` query parameter directly against
the application's assets directory with **no allowlist**. Any file whose name
is known (or guessable) inside that directory is served to any visitor.

Demonstrated:

```
GET /projects/download?file=staff_guide.pdf
-> "Staff onboarding guide — JWT config: see /internal/config (localhost only)"
```

The same document openly points to the internal config endpoint — the file
that anchors Finding 06.

Path traversal itself is hardened (tested `%2e%2e%2f`, `....//`,
`..%2f..%2fetc%2fpasswd` etc. — all answered `forbidden` or `not found`),
so the weakness is not traversal but the missing allowlist / generic error.

## Impact

- Any file in the served directory can be retrieved by unauthenticated users.
- Internal documents (like the staff guide) leak operational details that
  materially advance other attacks (Finding 02, Finding 06).
- `not found` vs `forbidden` responses act as an oracle distinguishing
  existing-but-blocked files from missing ones.

## Avoidance

- Serve downloads from an explicit allowlist of asset IDs/names.
- Keep sensitive documents out of the web-servable directory entirely.
- Return an identical generic error for both missing and denied files.
