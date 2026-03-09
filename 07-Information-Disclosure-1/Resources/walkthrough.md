# Information Disclosure 1

## Vulnérabilité

Même si le serveur ne nosu indiques pas le chemin, il y a beaucoup de page accessible en fouillant un peu.

On pourrait utiliser un outil spécialisé pour ca (un `web fuzzer`), mais on va commencer par chercher à la main avec des pages connues.


### Laisser l'addresse sur la porte

Un des plus évidents: `/admin`. On tombe sur une page avec un formulaire de connexion


### Suivre les robots

Le `/robots.txt`, un fichier utilisé dans le `Robots Exclusion Protocol`, il sert à indiquer aux `web crawler` quelles portions du site accéder.

Contenu:
```url
  User-agent: *
  Disallow: /whatever
  Disallow: /.hidden
```

On va bien évidemment tester `/whatever/` et `/.hidden/`, en se contrencant ici sur `whatever`

Certain serveur font ce qu'on appelle un `directory listing`, c'est à dire que s'il n'y a pas d'index quand un répertorie est demandé, ils affichent l'équivalent d'un `ls`.

### Whatever

En fouillant dans `/whatever/` on trouve le fichier `/whatever/htpasswd`, `htpasswd` est un fichier contenant les mot de passe de la `basic auth` d'un serveur Apache.

On trouve dedans `root:437394baff5aa33daa618be47b75cb49`

C'est un mot de passe haché, on va l'analyser avec [hashes.com](https://hashes.com/en/decrypt/hash) ou [crackstation](https://crackstation.net/):
- algorithme: `MD5`
- pas de sel (selon `crackstation`)
- valeur: `qwerty123@`

Beaucoup de chose à dire ici:
- `MD5` n'est plus considéré comme un algorithme sécurisé
- ne pas saler (ajout d'une valeur aléatoire lors du hash) les mot de passe réduit drastiquement la sécurité du hash
- un mot de passe aussi faible que `qwerty123@` ne devrait jamais être utilisé
- laisser un fichier contenant des mot de passe accessible est une erreur fatal.


## Prévention

Utiliser un algorithme moderne

Toujours saler les hashs

Implémenter une politique de mot de passe robuste

Ne pas laisser des fichiers contenants des mot de passe accessible...


## Ressources

[portswigger.net](https://portswigger.net/web-security/information-disclosure)

[web fuzzing](https://www.techtarget.com/searchSecurity/tip/Web-fuzzing-Everything-you-need-to-know)

[robots.txt](https://en.wikipedia.org/wiki/Robots.txt)
