#!/bin/bash

# apt install parallel shntool flac cuetools

PARAMS=$@
DIR=$(dirname "$PARAMS")
FILE=$(basename "$PARAMS")
CUEFILE=${FILE/ape/cue}
FLACFILE=${FILE/ape/flac}

cd "$DIR"
CURDIR=$(pwd)

if [ -f "$FILE" ]; then
  parallel -j1 ffmpeg -i {} -compression_level 8 {.}.flac ::: "$FILE"
  shnsplit -f "$CUEFILE" -t %n-%t -o flac "$FLACFILE"
  cuetag "$CUEFILE" [0-9]*.flac
else
  echo "File $FILE not found. Should be a .ape file."
fi
