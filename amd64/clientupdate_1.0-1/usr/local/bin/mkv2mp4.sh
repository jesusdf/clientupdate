#!/bin/bash
DIR=$(dirname "$1")
echo "Procesando ficheros en $DIR ...";
#find "${DIR}" -name \*.mkv -type f -exec ffmpeg -i "{}" -stats -vcodec copy -acodec copy "{}.mp4" \; 2>/dev/null;
find "${DIR}" -name \*.mkv -type f -exec mkvtrans.sh "{}" \;
DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal 'Conversión a MP4 finalizada';
