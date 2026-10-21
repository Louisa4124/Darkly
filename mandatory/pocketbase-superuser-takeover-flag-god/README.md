# Breach: pocketbase-superuser-takeover (god-granting breach)

**Severity:** Critical
**Yields a flag:** Yes — `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`
**This is the breach that allows becoming god.**

## Explanation

`stored-xss-bot-ssrf-flag` leaks the PocketBase **superuser credentials**.
With them, the entire backend is readable *and writable* via the standard PB
admin API — bypassing every application-level access check the FastAPI layer
enforces (IDOR, role gating, grade privacy, reset flow, ...).

The final step rotates the `god` account's (`sophie`) password through the
PB admin API — full account takeover of the highest-privileged application
account. Logging in as `sophie` then yields god status (the sidebar "Access
level" ladder reflects the user record) and unlocks the god-level pages,
where the `internal_audit` collection contains the final flag.

```
[reset-token leak] ─► student
   ▼ PATCH role=cadet
[cadet] ── /staff/dashboard ──► FLAG 1
   ▼ forged JWT (secret "42network")
[staff] ── /admin ─────────────► FLAG 2
   ▼ bot SSRF → /internal/config
[god creds + FLAG 3]
   ▼ PB superuser auth (this breach)
[PB superuser] ──► rotate sophie's password ──► login as sophie ──► GOD
   └── internal_audit collection ──► FLAG 4
```

## Exploitation script

See `exploit.sh` in this folder:

```bash
./exploit.sh
```

1. Authenticates as PB superuser (`admin@42network.local` /
   `Darkly42Admin!` — leaked by the SSRF breach) against
   `http://localhost:8090/api/admins/auth-with-password`.
2. Lists all 9 collections (`users, posts, comments, projects, grades,
   newsletter, agenda_imports, internal_config, internal_audit`).
3. Dumps the `internal_audit` collection → final flag
   `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`.
4. Rotates `sophie`'s password to take over the god account.

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
