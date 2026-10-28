# Open access

flag: `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`

Le robots.txt indique le chemin `/api/grades`, qui n'est pas accessible sans etre login.
Un fois login, il n'y a pas plus de protections:

```shell
curl -s -b "session=$cookie" 'http://localhost:4942/api/grades' | jq . | grep flag
```

On obtient alors le flag. Un `disallow` dans le robots.txt est purement informatif, ca ne protege rien!
