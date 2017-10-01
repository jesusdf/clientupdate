#!/bin/sh
URL="$1";
[[ $URL != */ ]] && URL="$URL/";
TOTAL=$(( `echo "$URL" | grep -o / | wc -l` - 3 ));
#wget -nH --cut-dirs=$TOTAL --wait=1 --limit-rate=200K -np -r -p -k -U Mozilla $1 
wget -nH --cut-dirs=$TOTAL --wait=1 -np -r -p -k -U Mozilla $1
