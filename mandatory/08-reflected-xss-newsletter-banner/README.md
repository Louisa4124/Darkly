# Breach: reflected-xss-newsletter-banner

**Target:** http://localhost:4942
**Severity:** Medium
**Flag:** none — this breach does not yield a flag

## How it works

`POST /newsletter` redirects to `/newsletter?email=<raw input>&msg=subscribed`,
and the success banner renders the `email` query parameter **unescaped**:

```html
<div class="alert alert-success">You're now subscribed with: <b>xsstest</b>@test.com</div>
```

The page's own HTML comments confirm the developers know about it
(`wil: define "unescaped". / emilie: someone subscribed with a <script> tag
last week... it worked.`).

The inconsistency is the tell: on the very same page the `<input value="...">`
field escapes the identical value correctly — the escaping is applied in one
output context but not the other.

## Steps to reproduce

Run `./exploit.sh [base_url]` (defaults to `http://localhost:4942`):

1. `POST /newsletter` with `email=<b>xsstest</b>@test.com` → 302 redirect with
   the raw value in `location: /newsletter?email=%3Cb%3Exsstest%3C/b%3E@test.com&msg=subscribed`.
2. GET the redirect target → banner shows `<b>xsstest</b>` rendered as HTML,
   while the input field shows `&lt;b&gt;xsstest&lt;/b&gt;`.

Exploit link: `/newsletter?email=<img src=x onerror=alert(document.cookie)>&msg=subscribed`
executes in any victim's browser.

Note: the URLs shown here and the fully percent-encoded URLs printed by the
script are two equivalent encodings of the same payload — both work.

## Impact

- A crafted link executes attacker JS on the site's origin for anyone who
  clicks it — session/cookie theft, phishing, actions on behalf of the victim.
- Proves a systemic output-encoding gap: same class of bug as the stored XSS
  in forum comments, just one-shot instead of persistent.

## How it could have been avoided

- Context-aware output escaping on **every** rendered user value — the input
  field already does it correctly; reuse that encoding for the banner.
- Enable auto-escaping globally in the templating engine rather than
  sprinkling manual `| escape` calls (which is how one context got missed).
- Validate emails server-side (reject values containing markup) in addition
  to encoding on output.
