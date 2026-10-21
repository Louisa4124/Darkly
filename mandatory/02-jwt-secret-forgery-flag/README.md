# Breach: jwt-secret-forgery (Gate 2: cadet → staff)

**Severity:** Critical
**Yields a flag:** Yes — `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

## Explanation

The deploy-log footer comments (they rotate per page; the jwt-secret line was
observed on `/login`, `/about`, `/forum`, `/agenda`, `/projects`,
`/newsletter`, `/internal`) state:

```html
<!-- v1.2.0 — sophie — initial platform. jwt secret was "42". wil changed it to "42network". progress. -->
```

The session cookie is an HS256 JWT (`{"alg":"HS256","typ":"JWT"}`) carrying
`sub`, `login`, `role`, `exp`. Signing a token with secret `"42network"` and
an arbitrary `login`/`role` is accepted by the server for authentication —
verified with every role value, including `visitor`. The privileged data then
comes from `/api/grades`: it returns all grade records of the token's `sub`,
including the "Darkly" meta-project whose `flag` field holds the flag.

`/admin` does **not** fall to the forgery: it stays `403 {"detail":
"Insufficient privileges"}` for forged `staff`/`god` tokens — that gate
validates the role against the server-side user record, not the JWT claim.
It unlocks only for a real DB-privileged session, e.g. the `god` account
taken over in breach 4, whose `/admin` panel displays this same flag.

Note: the account's PB record is untouched — the sidebar "Access level"
ladder widget reflects the user record, so the forgery is a pure
session-layer affair.

## Exploitation script

See `forge_jwt.py` and `exploit.sh` in this folder:

```bash
./exploit.sh http://localhost:4942 z4p1cnx47mfy50f jdoe cadet
```

Expected output:

```
[*] Forging JWTs (baseline role: cadet, then staff; secret: 42network)
[*] GET /api/grades with forged token
FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
[*] /admin with forged staff token (expected: stays 403 — DB-gated)
    /admin -> 403
```

`forge_jwt.py` builds the forged token (sub, login, and role supplied on
the command line); `exploit.sh` calls it twice — once with the account's
baseline role and once with `staff` — injects it as the `session` cookie,
pulls `/api/grades` for the flag, and probes `/admin` to show the gate holds.

## Impact

- Arbitrary `login`/`role` claim forgery → session-layer impersonation of any
  account, accepted for authentication at any role value.
- `/api/grades` leaks all grade records (including the flag-bearing meta-
  project) for whatever `sub` the forged token carries.
- Privileged pages (`/admin`, `/internal/config`) re-validate the role
  against the server-side user record and stay closed to forgeries.

## Fix recommendation

- Never disclose the signing secret anywhere client-reachable.
- Use a long, random, rotated secret (or asymmetric signing).
- Validate `role` against the server-side user record on every request.
