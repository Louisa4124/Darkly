# Breach: jwt-secret-forgery (Gate 2: cadet → staff)

**Severity:** Critical
**Yields a flag:** Yes — `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

## Explanation

Every page's HTML footer comments ("DEPLOY LOG") state:

```html
<!-- v1.2.0 — sophie — initial platform. jwt secret was "42". wil changed it to "42network". progress. -->
```

The session cookie is an HS256 JWT (`{"alg":"HS256","typ":"JWT"}`) carrying
`sub`, `login`, `role`, `exp`. Signing a token with secret `"42network"` and
an arbitrary `role` is accepted by the server. With `role: staff` the
`/admin` endpoint flips from 403 to 200, and the admin panel's submissions
table reveals the flag.

Note: the account's PB record is untouched — the sidebar "Access level"
ladder widget reflects the user record, so the forgery is a pure
session-layer escalation (cadet → staff).

## Exploitation script

See `forge_jwt.py` and `exploit.sh` in this folder:

```bash
./exploit.sh http://localhost:4942 z4p1cnx47mfy50f jdoe cadet
```

`forge_jwt.py` builds the forged token (`role` and baseline role supplied on
the command line); `exploit.sh` injects it as the `session` cookie and pulls
`/admin`.

## Impact

- Arbitrary role claim forgery → full session-layer impersonation of any
  role, including `staff` and `god` (the app-layer check on `/admin` is
  what gates the ladder here).
- `/api/grades` also leaks all grade records for the forged `sub`.

## Fix recommendation

- Never disclose the signing secret anywhere client-reachable.
- Use a long, random, rotated secret (or asymmetric signing).
- Validate `role` against the server-side user record on every request.
