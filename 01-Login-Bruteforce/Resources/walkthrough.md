# Login Bruteforce

## Vulnérabilité

Sur la page de Login, on remarque qu'il n'y a aucune limitation de tentative de connexion, on peut donc essayer de bruteforce le mot de passe.

Pour cela, on recupere une liste des mots de passe les plus couramment utiliser:

```url
    https://github.com/danielmiessler/SecLists/blob/master/Passwords/Common-Credentials/10k-most-common.txt
```

On voit dans la partie Networok de devtool un cookie du nom de 'I_am_admin'. On suppose alors que le username est `admin`

On cree ensuite un script en python qui test un a un tous les mots de passe, si le gif "WrongAnswer.gif" ne se trouve pas dans la page de reponse, alors on considere que l'on a peut etre trouver le mot de passe correct.

On obtients alors le mot de passe `shadow`, et en entrant ces coordonnees, on obtient notre premier flag


## Prévention

- Mettre un rate-limit, pour empecher de tester plusieurs mots de passe rapidement

- On peut aussi bloquer l'ip ou le compte au bout d'un certain nombre de fausse tentative

- Implementer une politique de mot de passe plus securise, avec au moins 12 caracteres, des nombres, des carateres speciaux... etc
