#!/bin/bash
PARAMS=$@
DIR=$(dirname "$PARAMS")
FILE=$(basename "$PARAMS")
STAB=stabilization_data$RANDOM
THREADS=$(getconf _NPROCESSORS_ONLN)

if [ -f /usr/src/mpv-build/ffmpeg_build/ffmpeg ]; then
    FFMPEG=/usr/src/mpv-build/ffmpeg_build/ffmpeg
else
    FFMPEG=ffmpeg
fi

cd $DIR
if [ -f $STAB ]; then
    rm -f $STAB
fi
${FFMPEG} -threads $THREADS -i "$FILE" -vf "vidstabdetect=stepsize=6:shakiness=8:accuracy=9:result=$STAB" -f null -
${FFMPEG} -threads $THREADS -i "$FILE" -vf "vidstabtransform=input=$STAB:zoom=1:smoothing=30,unsharp=5:5:0.8:3:3:0.4" -vcodec libx264 -preset slow -tune film -crf 18 -acodec copy "${PARAMS%.*}_stabilized.mp4"
rm -f $STAB

DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$FILE estabilizado.";
