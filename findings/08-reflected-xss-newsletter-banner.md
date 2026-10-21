# Finding 08 — Reflected XSS on /newsletter success banner

**Target:** http://localhost:4942
**Severity:** Medium
**Status:** Confirmed (unescaped echo demonstrated)
**Flag:** none (weakness of choice / supporting breach)

## Summary

`POST /newsletter` redirects to
`/newsletter?email=<raw input>&msg=subscribed`, and the page's success banner
renders the `email` query parameter **unescaped** inside an HTML div:

```html
<div class="alert alert-success">You're now subscribed with: <b>xsstest</b>@test.com</div>
```

The page's own HTML comments confirm the developers know (`wil: define
"unescaped". / emilie: someone subscribed with a <script> tag last week...
it worked.`). Notably the `<input value="...">` field on the same page IS
escaped — the escaping is inconsistent between output contexts.

## Steps to reproduce

```
curl -s 'http://localhost:4942/newsletter?email=%3Cimg%20src%3Dx%20onerror%3Dalert(1)%3E&msg=subscribed'
# banner renders: You're now subscribed with: <img src=x onerror=alert(1)>
```

## Impact

- A crafted link executes attacker JS on the site's origin when a victim
  clicks it (session/cookie theft if cookies are not httpOnly, phishing,
  actions on behalf of the victim).
- Demonstrates systemic output-encoding gaps: one context escaped, another not.

## Avoidance

- Apply context-aware output escaping on **every** rendered user value (the
  input field already does this correctly — reuse that encoding for the banner).
- Prefer templating engines with auto-escaping enabled globally.
- Validate emails server-side (reject values containing markup) in addition
  to escaping on output.
