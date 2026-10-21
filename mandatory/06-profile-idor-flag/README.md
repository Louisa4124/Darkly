# Breach: profile-idor (flag of choice)

**Severity:** High
**Yields a flag:** Yes — `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

## Explanation

`/profile/{id}` renders a "🔒 Private note" card for whichever profile `id`
is requested, with **no ownership check** — any authenticated user (cadet
sufficed) can view any other user's `private_note` field by enumerating ids
(ids are exposed in `/api/users` and in page HTML).

wil's (`id: k1asdfeditojrb4`) private note contains the flag:

```html
<div class="card-title" style="color:var(--yellow);">🔒 Private note</div>
<div ...>FLAG{1d0r_ur_pr0f1l3_1s_m1n3}</div>
<div ...>Only visible to wil — supposedly.</div>
```

The same class of leak extends to `/api/users/{id}`, which exposes
`pw_hint` (`md5(password)`) and `recovery_code` for every user
(not exercised by the script below). Note that `recovery_code` itself
holds a spare flag, `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`, readable for
benjamin, dorian and thanos via the same IDOR.

## Exploitation script

See `exploit.sh` in this folder:

```bash
./exploit.sh http://localhost:4942 cookies_jdoe.txt
```

`cookies_jdoe.txt` is the jdoe student session created by the login step in
`../05-password-reset-token-disclosure/`.

1. Lists user ids via `/api/users` and finds `wil`'s id.
2. Fetches wil's profile page and extracts the private note / flag.

## Impact

- Any user's private note, password hint and recovery code are readable
  cross-account.

## Fix recommendation

- Strip owner-only fields unless the requester's `sub` matches the profile
  `id` (or an explicit staff/god privilege enforced server-side).
