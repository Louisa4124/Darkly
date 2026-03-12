# Cookies

## Vulnérabilité

On voit dans le inspect qu'il y a un cookie dont la valeur est :
`i_am_admin` : `68934a3e9455fa72420237eb05902327`

En mettant cette valeur dans un decodeur on se rend compte que c'est un hash MD5
La valeur decrypter est `false`

On encrypte ensuite en MD5 `true`, ca donne `b326b5062b2f0e69046810717534cb09`

On remplace la valeur du cookie et quand on rafraichi la page, le flag apparait


## Prévention

- Verifier l'authenticite du cookie, en y implementant un mechanisme de signature (Exemple : jwt)
