#!/bin/zsh
# curl + regex, dont even need a cookie, how nice!

target='127.0.0.1:4942'
id=k1asdfeditojrb4

curl -s \
	http://$target/profile/$id |
	grep --color=always -E 'FLAG{.*}'
