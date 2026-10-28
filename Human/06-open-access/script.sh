#!/bin/zsh
# come on do a flip! curl smtg! but take a cookie first..

((${+1})) || {
	echo "missing cookie!"
	exit 1
}

target=127.0.0.1:4942

curl -si \
	-b "session=$1" \
	http://$target/api/grades |
	grep flag |
	jq . |
	grep --color=always -E 'FLAG{.*}'
