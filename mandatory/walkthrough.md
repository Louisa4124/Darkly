# Darkly — Mandatory Walkthrough

**Target:** `http://localhost:4942` (FastAPI app) + `http://localhost:8090` (PocketBase admin API)

**Environment — listener reachability (read before breaches 03/07):** the app
and its moderation bot run inside a VirtualBox NAT VM while the operator's
shell sits on the host. Probes arrive at the app from `10.0.2.2` (the
VirtualBox NAT gateway address of the host), so any exfil listener
(`xss-listener.py`) is reachable from the bot only at `10.0.2.2:<port>` —
`127.0.0.1` works only when the bot and the operator share a network
namespace. To re-detect the reachable address if the topology changes, use
the built-in source-IP oracle:

```bash
m="probe-$(date +%s)"; curl -s "http://localhost:4942/api/collect?c=$m" > /dev/null
curl -s "http://localhost:4942/api/collect" | \
  python3 -c "import json,sys; print(next(e['from'] for e in json.load(sys.stdin)['captured'] if e['data']=='<marker>'))"
```

The bot's visit cadence observed in this env is **1–2 min**.

**Goal:** recover 6 flags — 4 by escalating privileges step by step up to administrator (`god`) and on into the PocketBase superuser, plus 2 of choice.
**Result: 6/6 flags** (7 recovered counting the spare flag from the IDOR `recovery_code` leak).
**Result: 10/10 breaches**

Ladder: `visitor → student (breach 5) → cadet (breach 1) → staff (breach 2) → god (breach 3) → PocketBase superuser (breach 4)`.

---

## Part one — Breaches

The four breaches leading to admin privilege escalation come first, in ladder
order, then the six remaining breaches.

### Breach 1 — Self role escalation

> Repro: [01 — Self role escalation](01-self-role-escalation-flag/README.md) · script: `exploit.sh`

**Flag:** `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

Mass assignment on `PATCH /api/profile`: the self-update endpoint copies the
whole request body onto the user record without a field allowlist. The server
rejects `staff`/`admin` ("role not assignable") but not `cadet`, so a student
sets `{"role":"cadet"}` on their own profile. After re-login (the JWT caches
the old role), `/staff/dashboard` unlocks and its banner displays the flag.

### Breach 2 — JWT secret forgery

> Repro: [02 — JWT secret forgery](02-jwt-secret-forgery-flag/README.md) · scripts: `forge_jwt.py`, `exploit.sh`

**Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

Session JWTs are HS256 with payload `{sub, login, role, exp}`, and the signing
secret history is disclosed in a deploy-log HTML comment in the footer of most
pages (`"42"` → `"42network"`, current). Anyone who knows the secret can forge
a token with arbitrary `login`/`role` claims; the server accepts any forged
token for authentication — even `role: visitor` — and `/api/grades` then leaks
every grade record of the token's `sub`, including the "Darkly" meta-project
whose `flag` field holds the flag. Note: `/admin` itself stays `403 {"detail":
"Insufficient privileges"}` under any forged token — that gate validates the
role against the server-side user record, not the JWT claim (it unlocks only
for a real DB-privileged account, e.g. the `god` session from breach 4).

### Breach 3 — Stored XSS → bot SSRF

> Repro: [03 — Stored XSS bot SSRF](03-stored-xss-bot-ssrf-flag/README.md) · script: `ssrf-relay.sh`

**Flag:** `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

Chaining the stored XSS (breach 7) with a fetch-and-relay payload turns the
server-side moderation bot into an SSRF proxy: the bot's browser originates
from `127.0.0.1`, so its same-origin `fetch('/internal/config')` passes the
localhost-only gate that blocks every direct request (403). The exfiltrated
config JSON contains the flag and the **plaintext PocketBase superuser
credentials** used in breach 4. Alternative path: XXE on the `/agenda` XML
import (`xml.etree`, entities and all) gives the same SSRF from the server
itself.

### Breach 4 — PocketBase superuser takeover

> Repro: [04 — PocketBase superuser takeover](04-pocketbase-superuser-takeover-flag-god/README.md) · script: `exploit.sh`

**Flag:** `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`

The superuser credentials from breach 3 authenticate against the PocketBase
admin API (`http://localhost:8090/_/`, address leaked in the `/admin` panel's
HTML comment). Logging in with the superuser token grants unrestricted read/write
over all 9 collections — including editing any user's `role` straight in the
database — and the `internal_audit` collection holds the final ladder flag. Total
compromise of the data layer: highest-impact finding of the assessment.

### Breach 5 — Password reset token disclosure

> Repro: [05 — Password reset token disclosure](05-password-reset-token-disclosure/README.md) · script: `exploit.sh`

`POST /reset-password/request` returns the reset token in the `Location`
header of its 302 redirect — for any email, existing or not — and tokens are
deterministic (`md5`-derived), so any known email can be taken over with no
out-of-band step. Yields no flag: used against `jdoe@student.42.tech` it
provides the legitimate `student` session that is the foothold of the whole
ladder.

### Breach 6 — Profile IDOR

> Repro: [06 — Profile IDOR](06-profile-idor-flag/README.md) · script: `exploit.sh`

**Flag:** `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

`/profile/{id}` and `/api/users/{id}` fetch records by ID with no ownership
check: any authenticated user can read any other account's full record —
`private_note` (wil's contains the flag), `pw_hint` (`md5(password)`) and
`recovery_code` for every user. Bulk disclosure of private data, and a source
of hints that unlock further breaches.

**Spare flag:** `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` — the `recovery_code` of
some accounts (benjamin, dorian, thanos) holds it, confirming reset tokens are
`md5(email)`-derived (ties back to breach 5).

### Breach 7 — Stored XSS cookie theft

> Repro: [07 — Stored XSS cookie theft](07-stored-xss-cookie-theft-flag/README.md) · scripts: `post-payload.sh`, `xss-listener.py`

**Flag:** `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

Forum comments render user HTML unescaped ("HTML is supported"), and the
moderation bot (headless Chrome inside the VM) visits new/updated threads with
a live session and a **non-httpOnly `flag` cookie**. A one-time
`<img onerror=fetch(...)>` comment makes the bot execute the payload and
exfiltrate its cookies to our listener within 1–2 min (observed bot cadence —
see the Environment note above) — the flag plus a live
moderator JWT. Also the technical enabler of breach 3.

### Breach 8 — Reflected XSS newsletter banner

> Repro: [08 — Reflected XSS newsletter banner](08-reflected-xss-newsletter-banner/README.md) · script: `exploit.sh`

`POST /newsletter` redirects with the raw email in the query string, and the
success banner echoes it back unescaped — while the same value is correctly
escaped in the `<input value=...>` (inconsistent output encoding between
contexts). One crafted link runs attacker JS on the site origin for anyone who
clicks it. No flag, but the same bug class as breach 7.

### Breach 9 — Header / robots.txt info disclosure

> Repro: [09 — Header / robots.txt info disclosure](09-header-robots-info-disclosure/README.md) · script: `exploit.sh`

Every response leaks `x-pocketbase: http://localhost:8090`,
`x-42-internal: campus=paris` and version strings in `Server`/`x-powered-by`;
`robots.txt` enumerates `/admin`, `/staff`, `/internal`, `/backup`,
`/api/grades`, `/_/` and `/static/uploads/`. Pure reconnaissance
force-multiplier — exact DB admin address, stack versions for CVE lookup, and
a map of sensitive routes. No flag.

### Breach 10 — Unrestricted file download

> Repro: [10 — Unrestricted file download](10-unrestricted-file-download/README.md) · script: `exploit.sh`

`GET /projects/download?file=<name>` resolves the parameter directly against
the assets directory with no allowlist: any file in the directory can be
fetched by name by any *authenticated* user (anonymous requests are 302'd to
`/login`). Traversal sequences are blocked (verified: encoded `../` and
`....//` → 404 `not found`, absolute paths → 403 `forbidden`), but the
`not found` vs `forbidden` responses leak which paths exist — the
`staff_guide.pdf` found there names `/internal/config` and JWT hints,
materially advancing the other breaches. No flag.

---

## Annexes

### Annex A — Escalation graph

```
Visitor
   │  password reset token = md5(email), leaked in Location header
   ▼
Student
   │  PATCH /api/profile {"role":"cadet"} (allowlist gap)
   ▼
Cadet ──────────────── 🚩 FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
   │  forge JWT with leaked secret "42network" (any role accepted
   │  for auth; /admin stays DB-gated) → /api/grades
   ▼
Staff ──────────────── 🚩 FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
   │  stored XSS → bot SSRF relay → /internal/config (127.0.0.1)
   ▼
God ────────────────── 🚩 FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}
   │  superuser creds from /internal/config → PocketBase /_/
   ▼
PB Superuser ───────── 🚩 FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}

Side channels (flags of choice — any authenticated level):
   IDOR /profile/{id}   ── 🚩 FLAG{1d0r_ur_pr0f1l3_1s_m1n3}
   Stored XSS → bot     ── 🚩 FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}
   IDOR recovery_code   ── 🚩 FLAG{r3s3t_t0k3n_w4s_just_md5_lol}

7 flags total recovered (requirement: 6 — 4 escalation + 2 of choice)
```

### Annex B — Chain of trust

```
[reset-token leak] ──► student account (jdoe)
        │
        ▼
[PATCH role=cadet] ──► cadet ──► /staff/dashboard ──► FLAG 1
        │
        ▼
[JWT secret "42network" from deploy log] ──► forged token (any role) ──► /api/grades ──► FLAG 2
         │                                  (/admin stays 403 — gate checks the DB role)
        │
        ▼
[stored XSS → bot SSRF relay] ──► /internal/config ──► FLAG 3 + PB creds
        │
        ▼
[PB superuser auth] ──► /_/ collections ──► internal_audit ──► FLAG 4

(parallel, any auth level)
   ├── [IDOR /profile/{id}] ──► private_note ──► FLAG 5
   ├── [XSS in forum comments] ──► bot cookie theft ──► FLAG 6
   └── [IDOR recovery_code] ──► spare flag
```
