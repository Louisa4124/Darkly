#!/bin/zsh
# curl. again.

target='127.0.0.1:4942'

echo "Inspect /api/profile"
echo
curl -si http://$target/api/profile

echo
echo
echo
echo "Inspect /backup"
echo
curl -si http://$target/backup
