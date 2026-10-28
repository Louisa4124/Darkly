# XSS (again..)

Le formulaire de souscription de la newsletter est vulnerable aux XSS

```
<img src=x onerror=alert(1)>
```
