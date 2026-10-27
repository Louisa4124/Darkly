IDOR (Insecure Direct Object Reference)

Si on va sur le forum, et que l'on clique sur n'importe quel post fait par n'importe quel user (meme admin), on a acces a son profil et a toutes les informations dessus.
Aucune verification n'est faite pour savoir si le user connecte a le droit d'acceder a cette page.

Ainsi, si on va sur le profile de Wil:

```
    http://localhost:4942/profile/k1asdfeditojrb4
```

On peut voir une note supposement visible seulement par lui.
Le flag est contenu dans la note:

```
    FLAG{1d0r_ur_pr0f1l3_1s_m1n3}
```