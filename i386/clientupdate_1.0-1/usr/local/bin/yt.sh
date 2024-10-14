#!/bin/bash
yt-dlp --referer "$2" -f "bestvideo[ext!=webm][height <=? 1080]+bestaudio[ext!=webm]/best[ext!=webm]" --sub-lang es --write-sub -S res,vcodec:h264,acodec:aac,ext:mp4:m4a "$1"
