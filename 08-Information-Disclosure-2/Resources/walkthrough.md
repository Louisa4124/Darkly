# Information Disclosure 2

## Vulnérabilité

Même si le serveur ne nous indiques pas le chemin, il y a beaucoup de page accessible en fouillant un peu.

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

On va bien évidemment tester `/whatever/` et `/.hidden/`, en se contrencant ici sur `.hidden`

Certain serveur font ce qu'on appelle un `directory listing`, c'est à dire que s'il n'y a pas d'index quand un répertorie est demandé, ils affichent l'équivalent d'un `ls`.


### Hidden?

Un curl sur `/.hidden/` nous donne un directory listing avec une dizaine de liens dont les url semblent généré aléatoirement.

La stratégie ici est de cacher un élément secret au milieu d'une myriade d'éléments "dummy".

Passer des secrets dans un url aléatoire semble une bonne idée pour les sécuriser (avec une longueur suffisante on peut théoriquement les rendre impossible à brute force (surtout en rajoutant un rate-limit)).
Mais le fait de laisser le directory listing réduit drastiquement l'entropie et permet de brute force simplement.

```shell
  $> ./scrap.sh
  [...]
  Scrapping done. Trimming result...
  Hey, here is your flag : d5eec3ec36cf80dce44a896f961c1831a05526ec215693c8f2c39543497d4466
```


## Prévention

Désactiver le directory listing là où ce n'est pas nécessaire
Ne pas essayer de jouer au petit malin si on n'est pas assez malin


## Ressources

[portswigger.net](https://portswigger.net/web-security/information-disclosure)

[web fuzzing](https://www.techtarget.com/searchSecurity/tip/Web-fuzzing-Everything-you-need-to-know)

[robots.txt](https://en.wikipedia.org/wiki/Robots.txt)
