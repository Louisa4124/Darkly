# XSS

## Vulnérabilité

Sur la page de feedback `http://10.13.200.37/?page=feedback` on peut laisser un commentaire.
Les input utilisateur ne sont pas nettoyés, on peut donc faire du `Cross Site Scripting`.
L'idée est qu'on va laisser une commentaire contenant du code `JS` malicieux pour piéger d'autres utilisateurs.


## Prévention

Appliquer un assainissement (`sanitize`) des input utilisateur


## Ressources

[owasp xss](https://owasp.org/www-community/attacks/xss/)
