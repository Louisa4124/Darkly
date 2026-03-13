#!/bin/zsh
# scrap everythin in `.hidden`

url_base=http://localhost:8080/.hidden/

result_file="results.txt"


get_hidden () {
  local depth=$1
  local base=$2
  local slug=$3
  local url="$base$slug"

  tput clear

  echo -n "($depth) '$slug' -> "

  local links=($(curl -s -w "%{response_code}" $url | grep -io 'href=\"[a-z0-9]*/' | cut -c 7-))

  if [[ ${#links} -ge "3" ]]; then
    echo -n "found ${#links} links"
    for i in $links
    do
      get_hidden "$(( $depth + 1))" $url $i
    done
  else
    echo -n "no links to follow, "
  fi

  local readme=($(curl -s -w "%{response_code}" ${url}README))
  if [[ readme[${#readme}] -eq "200" ]]; then
    shift -p readme
    echo -n "found README: \"$readme\""
    echo $readme >> $result_file
  else
    echo -n "no README found."
  fi
}

if [[ -f $result_file ]]; then
  echo "$result_file already exist, skip scrapping"
  grep -vh -f pattern.txt $result_file
  exit 0
fi

echo "Start scrapping, it can take some time..."

get_hidden 0 $url_base

tput clear

echo "Scrapping done. Trimming result..."
grep -vh -f pattern.txt $result_file
