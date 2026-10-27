# JWT forgery

Dans le code HTML, on reytrouve le commentaire suivant:

```
v1.2.0 — sophie  — initial platform. jwt secret was "42". wil changed it to "42network". progress.
```

Le mot de passe est donc ecrit en clair dans le code.
On peut alors l'utiliser pour se faire passer pour un staff/admin.

On peut prendre un token de session student, aller sur [jwt.io](https://www.jwt.io/) et modifer le role.

Par exemple pour la route /api/grades trouvees dans robot.txt

On obtient alors le flag:

```
FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
```
