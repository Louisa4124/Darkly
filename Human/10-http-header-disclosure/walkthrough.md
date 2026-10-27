# HTTP header disclosure

Les reponses HTTP contiennent des headers inutiles divulguant des informations sensibles.


/api/profile
```
x-pocketbase: http://localhost:8090          # exact address of the DB admin API
x-42-internal: campus=paris                  # internal metadata
```

/backup
```
x-backup-agent: rsync/3.2.7
x-backup-schedule: daily@03:00
x-backup-dest: localhost:/opt/pocketbase/pb_data
x-backup-exclude: data/private_notes.txt          # mmmh? -> voir 11
x-last-backup: 2024-12-01T03:00:00Z
```
