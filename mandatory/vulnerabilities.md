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

**How it works.** The profile self-update endpoint copies the whole request
body onto the user record without a field allowlist, so a client adds
`{"role": "cadet"}` and the server dutifully changes its own role.

**Impact.** Direct self-service privilege escalation (gate 1) and,
combined with #2, any role in one step.

**Avoidance.** Explicit allowlists of editable fields (`name`, `avatar`,
`bio`…); role changes only through an admin-only endpoint with
server-side authorization; reject unknown fields.

## 4. IDOR on `/profile/{id}`

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
