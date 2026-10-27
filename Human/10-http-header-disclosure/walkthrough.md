# HTTP header disclosure

Les reponses HTTP contiennent des headers inutiles divulguant des informations sensibles.


```
x-pocketbase: http://localhost:8090          # exact address of the DB admin API
x-42-internal: campus=paris                  # internal metadata
```
