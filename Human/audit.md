# Audit

```tree
1. reset password
|
2. patch roles
|
3. XSS 1
|
4. XSS 2
|
5. pocketbase -> X
|
6. JWT forgery
|
7. IDOR
|
8. Unrestricted upload
|
9. XSS /newsletter
|
10. HTTP header disclosure
```

## Hints

### html comments

```html
<!-- DEPLOY LOG
  v1.3.7 — sophie  — "fixed session handling" (she didn't, wil checked)
  v1.3.6 — wil     — "added telemetry" (it's just a console.log)
  v1.3.5 — emilie  — "filed 12 issues" (wil closed 11 as wontfix)
  v1.3.4 — wil     — "disabled defusedxml temporarily" (that was 6 months ago)
  v1.3.3 — wil     — "quick fix on file upload" (removed the whitelist entirely)
  v1.2.0 — sophie  — initial platform. jwt secret was "42". wil changed it to "42network". progress.
-->
```

### robots.txt

```txt
User-agent: *
Disallow: /admin
Disallow: /staff
Disallow: /internal
Disallow: /backup
Disallow: /api/grades
Disallow: /_/
Disallow: /static/uploads/
```

## Privilege escalation

### 1. -> reset password

escalation: visitor -> student
flag: FLAG{r3s3t_t0k3n_w4s_just_md5_lol}
hints: forum's message
[detail](./01-password-reset-token-breach/walkthrough.md)

reset someone else password

### 2. update roles /api/roles

escalation: student -> cadet
flag: `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`
hints: /staff say PATH /api/profile
[details](./02-self-role-escalation-breach/walkthrough.md)

patch /api/profile to give yourself the `cadet` role

### 3. XSS injection 1

escalation: nop
flag: `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`
hints: forum's message about the moderation bot vulnerable to XSS
[details](./03-XSS-injection-1/walkthruogh.md)

the moderation bot is vulnerable to XSS injection (see forum comments)

### 4. XXS injection 2 - relay

escalation: nop
flag: `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`
hints: html comment: `NOTE: /internal/config restricted to localhost only. do not expose`
[details](./04-XSS-injection-2-internal-dump/walkthrough.md)

same but we will fetch the restricted `/internal/config` and forward it to us
give the pockebase creds + flag

### 5. PocketBase

escalation: god
flag: `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`
hints: breach#4 + robots.txt `/_/`
[details](./05-pocketbase/walkthrough.md)

authenticate to pocketbase with the web ui
flag in `internal_audit`, others flags visible can change own role, and become `god`.

## Others breach

### 6. JWT forgery

/!\ -> just robot.txt not protect

flag: FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
[details](./06-jwt-secret-breach/walkthrough.md)

update jwt right and get /api/grades for darkly

### 7. IDOR /profile/id

flag: FLAG{1d0r_ur_pr0f1l3_1s_m1n3}
[details](./07-profile-idor-breach/walkthrough.md)

### 8. Unrestricted upload

flag: `FLAG{unr3str1ct3d_upl0ad_g0_brrr}`
[details](./08-unrestricted-upload/walkthrough.md)

upload anything as profile picture

### 9. XSS /newsletter

flag: nop
[details](./09-xss-newsletter/walkthrough.md)

vulnerabilite XSS in form

### 10. Header Disclosure

flag: nop
[details](./10-http-header-disclosure/walkthrough.md)

http header disclosure


### 11. Path traversal

flag:
[details]

## hints ?

in suscribe email (see comment in /staff/dashboard: `someone subscribed "' OR 1=1--@evil.com"`)
