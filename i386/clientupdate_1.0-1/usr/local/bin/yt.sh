#!/bin/bash
yt-dlp -f "bestvideo[ext!=webm][height <=? 1080]+bestaudio[ext!=webm]/best[ext!=webm]" --sub-lang es --write-sub "$1"
