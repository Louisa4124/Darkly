# Breach: password-reset-token-disclosure

**Severity:** Critical
**Yields a flag:** No — this breach yields a *valid student session*, which is
the entry point of the whole ladder.

## Explanation

`POST /reset-password/request` returns the password-reset token directly in
the `Location` header of its 302 redirect — for **any** email, existing or
not. No email delivery / out-of-band step is required. Combined with the
deterministic nature of the tokens (`md5`-derived), this allows full account
takeover for any known email.

We used it against `jdoe@student.42.tech` to obtain a legitimate `student`
session (`role: student`), the bottom rung of the privilege ladder.

## Exploitation script

See `exploit.sh` in this folder:

```bash
./exploit.sh http://localhost:4942 jdoe@student.42.tech 'Pwned1234!'
```

1. Requests a reset for the victim email and extracts the token from the
   `Location` header.
2. Confirms the new password with the token.
3. Logs in as the victim and saves the session cookie to `cookies_jdoe.txt`.

## Impact

- Full account takeover of any account with a known email.
- Provides the initial authenticated foothold used by every later breach
  (role escalation, forged JWT, IDOR, XSS).

## Fix recommendation

- Never return the reset token synchronously; deliver it only out-of-band
  (email inbox).
- Return the same generic response regardless of account existence.
- Use high-entropy, single-use, short-lived tokens; rate-limit the endpoint.
