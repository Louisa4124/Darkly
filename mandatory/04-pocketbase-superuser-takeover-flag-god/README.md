# Breach: pocketbase-superuser-takeover (god-granting breach)

**Severity:** Critical
**Yields a flag:** Yes — `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`
**This is the breach that allows becoming god.**

## Explanation

`03-stored-xss-bot-ssrf-flag` leaks the PocketBase **superuser credentials**.
With them, the entire backend is readable *and writable* via the standard PB
admin API — bypassing every application-level access check the FastAPI layer
enforces, such as IDOR, role gating, and grade privacy.

The superuser token grants direct read access to every collection — including
`internal_audit`, which holds the final flag. As a separate demonstration of
write access, the script also rotates the `god` account's (`sophie`) password
through the PB admin API — full account takeover of the highest-privileged
application account. Logging in as `sophie` then yields god status (the
sidebar "Access level" ladder reflects the user record) and unlocks the
god-level pages.

```
[reset-token leak] ─► student
   ▼ PATCH role=cadet
[cadet] ── /staff/dashboard ──► FLAG 1 = FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
   ▼ forged JWT (secret "42network")
[staff] ── /admin ─────────────► FLAG 2 = FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
   ▼ bot SSRF → /internal/config
[god creds + FLAG 3 = FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}]
   ▼ PB superuser auth (this breach)
[PB superuser] ──► internal_audit collection ──► FLAG 4 = FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}
   ▼ rotate sophie's password (write-access demo)
[login as sophie ──► GOD] — no new flag (see walkthrough.md Annex A)
```

## Exploitation script

See `exploit.sh` in this folder:

```bash
./exploit.sh
```

**Prerequisites:** the FastAPI app must be running on `http://localhost:4942`
and PocketBase on `http://localhost:8090`; `curl` must be available on `PATH`.

**Side effects:** writes `cookies_sophie.txt` in the current working
directory, and rotates `sophie`'s password to `G0dPwn3d!2024` — after the
run, the god account logs in with `sophie@42network.local` / `G0dPwn3d!2024`.

1. Authenticates as PB superuser (`admin@42network.local` /
   `Darkly42Admin!` — leaked by the SSRF breach) against
   `http://localhost:8090/api/admins/auth-with-password`.
2. Lists all 9 collections (`users, posts, comments, projects, grades,
   newsletter, agenda_imports, internal_config, internal_audit`).
3. Dumps the `internal_audit` collection → final flag
   `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`.
4. Rotates `sophie`'s password to `G0dPwn3d!2024` to take over the god
   account, then logs in on the app as `sophie@42network.local` to
   demonstrate the write-access takeover.

Note: `api/admins/auth-with-password` is the legacy PocketBase admin
endpoint (works on the bundled PB version; PB ≥ 0.23 uses
`/api/collections/_superusers/auth-with-password`).

## Impact

- **God account takeover**: `sophie`'s password is rotated; logging in as
  `sophie` grants the highest-privileged application account.
- Every app-layer vuln becomes trivial once PB superuser is owned: role
  escalation, private notes, recovery codes, config, audit.
- Full database read/write across all 9 collections.

## Fix recommendation

- Never store superuser credentials in an application-readable config
  endpoint; keep them in env vars outside the DB / separate secret store.
- Restrict PocketBase to localhost binding (it currently listens on
  `0.0.0.0:8090`) and firewall it off from user networks.
- Audit-log rows should not carry flag material either — the flag sits in an
  audit note.
