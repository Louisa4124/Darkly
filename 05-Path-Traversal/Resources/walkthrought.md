# Path Traversal

## Vulnérabilité

En suivant le schema pour changer de page (exemple: `index.php?page=survey`), on peut accéder à des fichier qui ne devraient pas être accessible.

On peut spécifier un chemin parent avec `../` et remonter d'un niveau dans le système de fichier. Le but va être de remonter à la racine et de viser un fichier contenant des infos sensible, comme `/etc/passwd` ou `/etc/shadow`


On trouve le flag avec l'url:

```url
  http://[...]/index.php?page=../../../../../../../etc/passwd
```


## Prévention

Ne pas passer un input utilisateur à des appels systèmes manipulant les fichiers.
Chroot/limiter les fichier pouvant être servit/envoyé à certains répertoires précis.

Notons que sur un système linux bien configuré, le process du serveur web ne devrait pas avoir les permissions de lire les fichier les plus sensible.


## Ressources

[owasp](https://owasp.org/www-community/attacks/Path_Traversal)
