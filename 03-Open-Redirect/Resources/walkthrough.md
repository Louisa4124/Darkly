# Redirections Ouvertes (Open Redirect)

## Vulnérabilité

Utilisation d'une redirection non protégée pour piéger un utilisateur

Le site ne vérifie pas vers où il redirige, on peut lui donner un faux site et envoyer le lien dans une campagne de phising.
Le lien sera légitime (il pointe bien vers le vrai site), mais il redirige desuite vers un site malicieux

On peut voir la querystring utilisé pour les redirections:

![capture d'écran montrant l'url de redirection](screenshot.png)


Example d'url malicieux

```http
  http://[...]/index.php?page=redirect&site=malicious
```

## Prévention

Il faut simplement rajouter une validation des paramètres de redirection.

Par exemple:
- whitelist des host
- bloquer les protocols dangeureux (`javascript:`, `data:`, ..)
- destination de repli en cas d'erreur
- éviter les paramètres de redirections directement dans les urls


## Ressources

[Explication des Redirections Ouvertes](https://www.it-connect.fr/securite-des-applications-web-vulnerabilite-open-redirect/)

[Bonnes pratiques contre les Redirections Ouvertes](https://www.stackhawk.com/blog/what-is-open-redirect/#best-practices-to-prevent-open-redirect-vulnerabilities)
