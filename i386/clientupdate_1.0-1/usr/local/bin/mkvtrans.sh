#!/bin/bash
DIR=$(dirname "$1")
FILE=$(basename "$1")
SUBS=mysubs.${1##*.}
THREADS=$(getconf _NPROCESSORS_ONLN)

cd $DIR
if [ -f $SUBS ]; then
    rm -f $SUBS
fi
ln -s "$FILE" $SUBS
ffmpeg -threads $THREADS -i "$FILE" -vf "subtitles=$SUBS,scale=1280:720" -stats -c:v h264_nvenc -r ntsc -profile:v high -level 4.0 -rc cbr -acodec copy "${1%.*}.mp4" || ( rm -f "${1%.*}.mp4" && ffmpeg -threads $THREADS -i "$FILE" -vf subtitles=$SUBS -stats -c:v libx264 -r ntsc -profile:v high -preset superfast -level 4.0 -rc cbr -acodec copy "${1%.*}.mp4" ) || ( rm -f "${1%.*}.mp4" && ffmpeg -threads $THREADS -i "$FILE" -stats -vcodec copy -acodec copy "${1%.*}.mp4" )
rm -f $SUBS

DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$FILE convertido a MP4.";
