#!/bin/bash
DIR=$(dirname "$1")
FILE=$(basename "$1")
SUBS=mysubs.${1##*.}
NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)
THREADS=$(getconf _NPROCESSORS_ONLN)

cd $DIR
if [ "${NVIDIA_GPU}" -eq "0" ]; then
    ffmpeg -threads $THREADS -i "$FILE" -stats -vcodec copy -acodec copy "${1%.*}.mp4"
else
    ln -s "$FILE" $SUBS
    ffmpeg -threads $THREADS -i "$FILE" -vf subtitles=$SUBS -stats -c:v h264_nvenc -level 4.0 -rc cbr -acodec copy "${1%.*}.mp4"
    rm -f $SUBS
fi
DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$FILE convertido a MP4.";
