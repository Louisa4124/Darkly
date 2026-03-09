# Bad Password Recovery

## Vulnérabilité

Sur la page de recovery de mot de passe, on peut trouver un champ `input` avec le type `hidden`.
Le fait que l'input ne soit pas visible alors qu'on s'attend à en avoir un est indice, cette page est suspicieuse.

![Capture d'écran montrant le code HTML](screenshot.png)

L'input est paramétré pour renvoyer un lien (?) de réinitialisation pour l'admin du site (indice : le mail est `webmaster@borntosec.com`), mais la valeur de son mail est hardcodé dans le front et n'est probablement pas validé dans le back

La validation des données du formulaire n'est faite que dans le front, on peut supprimer la taille maximum de l'input et changer l'addresse mail

## Prévention

Une page de récupération de mot de passe devrait juste envoyé la requête au back, le back se charge de valider la légitimité de la requête.
