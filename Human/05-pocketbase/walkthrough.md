# pocketbase

flag: `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`

lien de pocketbase visible dans /staff/dashboard
un chemin ne renvoit a rien dans le robots.txt: `/_/` Si on essayait ce chemin avec pocketbase plutot?
`http://127.0.0.1:8090/_/` renviot vers une page de connection de pocketbase

email: admin@42network.local
password: Darkly42Admin!

grace aux creds qu'on a obtenu jsute avant, on peut se connecter et changer son role en `god`, et obtenir le dernier flag

## shell

```shell
pb_target='127.0.0.1:8090'

curl -s "http://$pb_target/api/admins/auth-with-password" \
  -H 'Content-Type: application/json' \
  -d '{"identity":"admin@42network.local","password":"Darkly42Admin!"}'

pb_token='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3OTQzMDkwODEsImlkIjoiMmYyZzl1b3VycTNwMG1iIiwidHlwZSI6ImFkbWluIn0.S9DUq9qb5j05B0MKs_xJ4zVZ5dxVD0Qe-sUi-hktS4M'
```
