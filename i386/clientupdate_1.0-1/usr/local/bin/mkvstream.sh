#!/bin/bash

# Path and file stuff

PARAMS=$@
DIR=$(dirname "$PARAMS")
OUTPUT_DIR="stream-ready"
NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)
cd "$DIR"

FILE=$(basename "$PARAMS")
NEWFILE=${FILE%.*}.mkv
SUBS=mysubs$RANDOM.${PARAMS##*.}
THREADS=$(getconf _NPROCESSORS_ONLN)

# File information

VIDEO_FORMAT=$(/usr/bin/mediainfo --Output="Video;%Format%" "$FILE")
VIDEO_PROFILE=$(/usr/bin/mediainfo --Output="Video;%Format_Profile%" "$FILE")
VIDEO_WIDTH=$(/usr/bin/mediainfo --Output="Video;%Width%" "$FILE")
VIDEO_HEIGHT=$(/usr/bin/mediainfo --Output="Video;%Height%" "$FILE")
AUDIO_FORMAT=$(/usr/bin/mediainfo --Output="Audio;%Format%" "$FILE")

# Bitrate measuring

FRAME_PIXELS=$(( $VIDEO_WIDTH * $VIDEO_HEIGHT ))
OPTIMAL_BITRATE=$(( $FRAME_PIXELS * 2 ))
#VBITRATE=$(/usr/bin/mediainfo --Output="Video;%BitRate%" "$FILE")
VBITRATE=$OPTIMAL_BITRATE
VMINBITRATE=$(( $OPTIMAL_BITRATE / 2 ))
VMAXBITRATE=$(( $FRAME_PIXELS * 3 ))
ABITRATE=$(/usr/bin/mediainfo --Output="Audio;%BitRate%" "$FILE" | cut -b 1-6)

#if (( $VBITRATE > $OPTIMAL_BITRATE )); then
#    VBITRATE=$OPTIMAL_BITRATE
#fi
if (( $ABITRATE > 192000 )); then
    ABITRATE="192k"
fi

# Encoding parameters

HWACCEL=""
VDECODER=""
VDECODER_FORMAT=""
VENCODER="-c:v libx264"
VENCODER_FORMAT=""
AENCODER="-acodec aac -c:a aac "
AENCODER_FORMAT="-b:a $ABITRATE -ac 2 -bufsize 1M"

MSG=""

if [ -f /usr/src/mpv-build/ffmpeg_build/ffmpeg ]; then
    FFMPEG=/usr/src/mpv-build/ffmpeg_build/ffmpeg
else
    FFMPEG=ffmpeg
fi

# GPU acceleration

if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
    #HWACCEL=" -hwaccel cuda -hwaccel_output_format cuda "
    #VENCODER=h264_nvenc
    #HWACCEL=" -hwaccel cuvid "
    #VDECODER="-c:v h264_cuvid"
    #VDECODER_FORMAT="" 
    #VDECODER_FORMAT="-resize 1920x1080"
    VENCODER="-c:v h264_nvenc"
    VENCODER_FORMAT="-preset 4 -tune 1 -pix_fmt yuv420p -profile 2 -level 40 -pass 2 -rc 1 -coder 1 -b_ref_mode 2 -b:v $VBITRATE -minrate $VMINBITRATE -maxrate $VMAXBITRATE"
    #VENCODER_FORMAT="-preset p4 -tune 1 -vf scale=640:-2"
fi

# Performance optimization, if the format is already the desired one, just copy the stream.

# AVC video and NOT 10 bit source
if [ "$VIDEO_FORMAT" == "AVC" ] && [ ! "${VIDEO_PROFILE%@*}" == "High 10" ]; then
    VDECODER=""
    VDECODER_FORMAT=""
    VENCODER="-c:v copy"
    VENCODER_FORMAT=""
fi

# AAC audio
if [ "$AUDIO_FORMAT" == "AAC" ]; then
    AENCODER="-c:a copy"
    AENCODER_FORMAT=""
fi

if [ -d "$FILE" ]; then

    # Directory
    echo "Looking for files in $DIR..."
    find "$DIR" -type f \( -iname \*.mkv -o -iname \*.avi -o -iname \*.mp4 \) -exec "$0" "{}" \;
    
    MSG="Folder transcoding finished: $FILE"

elif [ -f "$FILE" ]; then

    # Single file
    echo "Encoding file $FILE..."
    
    mkdir "$OUTPUT_DIR" 2>/dev/null
    
    # h264
    echo "Video Format: ${VIDEO_WIDTH}x${VIDEO_HEIGHT} $VIDEO_FORMAT $VIDEO_PROFILE"
    echo "Audio Format: $AUDIO_FORMAT"
    echo "Video encoding parameters: $VENCODER $VENCODER_FORMAT"
    echo "Audio encoding parameters: $AENCODER $AENCODER_FORMAT"
    
    ${FFMPEG} -analyzeduration 100M -probesize 100M -stats -vsync passthrough -y -hide_banner -loglevel error $HWACCEL $VDECODER $DECODER_FORMAT -i "$FILE" -threads $THREADS $VENCODER $VENCODER_FORMAT -passlogfile /tmp/mkvstream  -metadata title="" -metadata comment="" -map 0 $AENCODER $AENCODER_FORMAT "$OUTPUT_DIR/$NEWFILE" && MSG="Transcoding finished: $FILE" || MSG="Transcoding failed: $FILE"
    
else
    MSG="Path not found: $FILE"
fi

echo "$MSG"
DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$MSG";


