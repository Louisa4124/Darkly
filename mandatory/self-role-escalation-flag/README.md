# Breach: self-role-escalation (Gate 1: student → cadet)

**Severity:** High
**Yields a flag:** Yes — `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

## Explanation

`PATCH /api/profile` accepts a `role` field directly from the client. The
server rejects `staff`/`admin` ("role not assignable") but **not** `cadet`,
which is also a privileged tier. This is a real, persisted role change — not
just a forged token — and it unlocks the "Staff area" nav item and
`/staff/dashboard`.

`/api/docs-internal` openly documents the writable fields and valid role
values:

```json
{"writable_fields":["first_name","last_name","campus","avatar","role"],
 "role_values":["visitor","student","cadet","staff","god"],
 "note":"role writable via PATCH /api/profile"}
```

After re-login (the session JWT caches the old role), `/staff/dashboard`
shows the banner with the first ladder flag.

## Exploitation script

See `exploit.sh` in this folder:

```bash
./exploit.sh http://localhost:4942 cookies_jdoe.txt
```

1. Escalates own role via `PATCH /api/profile {"role":"cadet"}`.
2. Re-logs in to refresh the session JWT.
3. Fetches `/staff/dashboard` and extracts the flag from the banner.

## Impact

- First rung of the privilege ladder: `student → cadet`.
- Also exposes `/api/users` (full user directory) and `/api/docs-internal`
  (internal API schema) to any authenticated user.

## Fix recommendation

- Block **all** elevated roles from self-service PATCH, not just
  `staff`/`admin`; role changes belong in a privileged workflow.
- Require the actual target privilege level (staff/god) for `/api/users`
  and `/api/docs-internal`.
