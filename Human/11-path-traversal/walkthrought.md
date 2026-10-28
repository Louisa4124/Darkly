# Path traversal

flag: `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}`

On a trouvé le lien de téléchargement sur `/projects`.
Grâce aux headers HTTP on a le nom d'un ficher _privé_ à chercher `private_notes.txt`.

Plus qu'à tester de sortir de se balader et hop!

```shell
curl -si -b "session=$cookie" http://$target/projects/download'?file=../private_notes.txt'
```

Un serveur prennant un chemin de fichier doit restreindre les chemins reçu et confiner
le dossier de téléchargement.
