# Finding 04 — IDOR on /profile/{id} leaks another user's private note → FLAG 3

**Target:** http://192.168.1.74:4942
**Severity:** High
**Status:** Confirmed exploitable
**Flag:** `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

## Summary

`/profile/{id}` renders a "🔒 Private note" card for whichever profile `id`
is requested, with no ownership check — any authenticated user (cadet role
sufficient) can view any other user's `private_note` field by guessing/
enumerating their id (ids are exposed in `/api/users` and in page HTML,
e.g. forum post authors, dashboard user table links).

wil's (`id: k1asdfeditojrb4`) private note contains the flag.

## Steps to reproduce

1. Be logged in (any role; tested with `cadet` from Finding 03).
2. List user ids via `/api/users` (Finding 03) or the staff dashboard table —
   `wil` → `k1asdfeditojrb4`.
3. Request wil's profile page directly:

   ```
   curl -s -b cookies_jdoe.txt http://192.168.1.74:4942/profile/k1asdfeditojrb4
   ```

4. Response includes:
   ```html
   <div class="card-title" style="color:var(--yellow);">🔒 Private note</div>
   <div ...>FLAG{1d0r_ur_pr0f1l3_1s_m1n3}</div>
   <div ...>Only visible to wil — supposedly.</div>
   ```

Checked other users' profiles (sophie, moderator, students) — only wil's had
a populated `private_note`; everyone else's was empty, so this is specifically
an IDOR demo planted on the wil account.

## Fix recommendation

- `private_note` (and any owner-only field) must be stripped from the
  response unless the requester's `sub` matches the profile `id` (or the
  requester has an explicit staff/admin privilege, enforced server-side).
