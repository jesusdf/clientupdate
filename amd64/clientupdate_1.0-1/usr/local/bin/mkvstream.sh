#!/bin/bash

CONFIG_FILE=/etc/default/clientupdate
if [ -f ${CONFIG_FILE} ]; then
    # Load custom configuration options.
    . ${CONFIG_FILE}
fi

# Path and file stuff

NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)
THREADS=$(getconf _NPROCESSORS_ONLN)

PARAMS=$@
DIR=$(dirname "$PARAMS")
OUTPUT_DIR="stream-ready"
FILE=$(basename "$PARAMS")
NEWFILE=${FILE%.*}.mkv
#SUBS=mysubs$RANDOM.${PARAMS##*.}

cd "$DIR"
CURDIR=$(pwd)

if [ -d "$FILE" ]; then

    # Directory
    echo "Looking for files in $CURDIR ..."
    find "$CURDIR" -type f \( -iname \*.mkv -o -iname \*.avi -o -iname \*.mp4 -o -iname \*.ogm \) -exec "$0" "{}" \;
    
    MSG="Folder transcoding finished: $FILE"
    echo "$MSG"
    DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$MSG";
    exit 0

fi

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
#ABITRATE=$(/usr/bin/mediainfo --Output="Audio;%BitRate%" "$FILE" | cut -b 1-6)
ABITRATE="192k"

#if (( $VBITRATE > $OPTIMAL_BITRATE )); then
#    VBITRATE=$OPTIMAL_BITRATE
#fi
#if (( $ABITRATE > 192000 )); then
#    ABITRATE="192k"
#fi

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
    # Tests
    #HWACCEL=" -hwaccel cuda -hwaccel_output_format cuda "
    #VENCODER=h264_nvenc
    #HWACCEL=" -hwaccel cuvid "
    #VDECODER="-c:v h264_cuvid"
    #VDECODER_FORMAT="" 
    #VDECODER_FORMAT="-resize 1920x1080"
    #VENCODER_FORMAT="-preset p4 -tune 1 -vf scale=640:-2"
    
    if [ "$MKVSTREAM_ENCODER" == "h265" ]; then
    
        # h265
        VENCODER="-c:v hevc_nvenc"
        #VENCODER_FORMAT="-rc vbr -cq 24 -qmin 24 -qmax 24 -profile:v main10 -pix_fmt p010le -pass 1 -rc 1 -coder 1 -b_ref_mode 2 -b:v $VBITRATE -minrate $VMINBITRATE -maxrate $VMAXBITRATE"
        #VENCODER_FORMAT="-rc vbr -profile:v main10 -pix_fmt p010le -pass 1 -rc 1 -coder 1 -b_ref_mode 2 -b:v $VBITRATE -minrate $VMINBITRATE -maxrate $VMAXBITRATE"
        VENCODER_FORMAT="-preset 4 -tune 1 -pix_fmt yuv420p -profile:v main10 -level 5.1 -pass 1 -rc 1 -coder 1 -b_ref_mode 2 -b:v $VBITRATE -minrate $VMINBITRATE -maxrate $VMAXBITRATE"
        
    else
        
        # h264
        VENCODER="-c:v h264_nvenc"
        VENCODER_FORMAT="-preset 4 -tune 1 -pix_fmt yuv420p -profile 2 -level 40 -pass 1 -rc 1 -coder 1 -b_ref_mode 2 -b:v $VBITRATE -minrate $VMINBITRATE -maxrate $VMAXBITRATE"
        
    fi
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

if [ -f "$FILE" ]; then

    # Single file
    echo "Encoding file $FILE..."
    
    mkdir "$OUTPUT_DIR" 2>/dev/null
    
    # h264
    echo "Video Format: ${VIDEO_WIDTH}x${VIDEO_HEIGHT} $VIDEO_FORMAT $VIDEO_PROFILE"
    echo "Audio Format: $AUDIO_FORMAT"
    echo "Video encoding parameters: $VENCODER $VENCODER_FORMAT"
    echo "Audio encoding parameters: $AENCODER $AENCODER_FORMAT"

    ${FFMPEG} -hide_banner -loglevel error -stats -analyzeduration 100M -probesize 100M -vsync passthrough -y $HWACCEL $VDECODER $DECODER_FORMAT -i "$FILE" -threads $THREADS $VENCODER $VENCODER_FORMAT -passlogfile /tmp/mkvstream$RANDOM -metadata title="" -metadata comment="" -map 0 $AENCODER $AENCODER_FORMAT "$OUTPUT_DIR/$NEWFILE" && MSG="Transcoding finished: $FILE" || MSG="Transcoding failed: $FILE"
    
else
    MSG="Path not found: $FILE"
fi

echo "$MSG"
DISPLAY=:0 /usr/bin/notify-send -i dialog-information -u normal "$MSG";


