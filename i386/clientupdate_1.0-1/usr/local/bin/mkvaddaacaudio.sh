#!/bin/bash

CONFIG_FILE=/etc/default/clientupdate
if [ -f ${CONFIG_FILE} ]; then
    # Load custom configuration options.
    . ${CONFIG_FILE}
fi

PARAMS=$@

# Path and file stuff

NVIDIA_GPU=$(lspci | grep NVIDIA | wc -l)
THREADS=$(getconf _NPROCESSORS_ONLN)

DIR=$(dirname "$PARAMS")
OUTPUT_DIR="streamready"
FILE=$(basename "$PARAMS")
NEWFILE=${FILE%.*}.mkv
#SUBS=mysubs$RANDOM.${PARAMS##*.}
TMPAUDIO=audio$RANDOM.${PARAMS##*.}

cd "$DIR"
CURDIR=$(pwd)

if [ -d "$FILE" ]; then

    # Directory
    echo "Looking for files in $CURDIR ..."
    find "$CURDIR" -type f \( -iname \*.mkv -o -iname \*.avi -o -iname \*.mp4 -o -iname \*.ogm \) -not -path "$CURDIR/$OUTPUT_DIR/*" -exec "$0" "{}" \;
    
    MSG="Folder transcoding finished: $FILE"
    echo "$MSG"
    DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$MSG";
    exit 0

fi

# File information

AUDIO_FORMAT=$(/usr/bin/mediainfo --Output="Audio;%Format%" "$FILE")
AUDIO_CHANNELS=$(/usr/bin/mediainfo --Output="Audio;%Channel(s)%" "$FILE" | cut -c1)

# Bitrate measuring

#ABITRATE=$(/usr/bin/mediainfo --Output="Audio;%BitRate%" "$FILE" | cut -b 1-6)
ABITRATE="192k"

#if (( $ABITRATE > 192000 )); then
#    ABITRATE="192k"
#fi

# Encoding parameters

AENCODER="-acodec aac -c:a aac "
AENCODER_FORMAT="-b:a $ABITRATE -ac $AUDIO_CHANNELS -bufsize 1M"

MSG=""

if [ -f /usr/src/mpv-build/ffmpeg_build/ffmpeg ]; then
    FFMPEG=/usr/src/mpv-build/ffmpeg_build/ffmpeg
else
    FFMPEG=ffmpeg
fi

# Performance optimization, if the format is already the desired one, just copy the stream.

# AAC audio
if [ "$AUDIO_FORMAT" == "AAC" ]; then
    AENCODER="-c:a copy"
    AENCODER_FORMAT=""
fi

if [ -f "$FILE" ]; then

    # Single file
    echo "Encoding file $FILE..."
    
    mkdir "$OUTPUT_DIR" 2>/dev/null
    
    echo "Audio Format: $AUDIO_FORMAT"
    echo "Audio encoding parameters: $AENCODER $AENCODER_FORMAT"

    ${FFMPEG} -hide_banner -loglevel error -stats -i "$FILE" -threads $THREADS -map 0:a $AENCODER $AENCODER_FORMAT "$OUTPUT_DIR/$TMPAUDIO" && MSG="Transcoding finished: $FILE" || MSG="Transcoding failed: $FILE"
    /usr/bin/mkvmerge -o "$OUTPUT_DIR/$NEWFILE" "$FILE" "$OUTPUT_DIR/$TMPAUDIO"
    rm -f "$OUTPUT_DIR/$TMPAUDIO"
    
else
    MSG="Path not found: $FILE"
fi

echo "$MSG"
DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$MSG";


