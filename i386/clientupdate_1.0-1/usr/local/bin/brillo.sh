#!/bin/bash
#xrandr --output HDMI-0 --brightness 0.8
#xrandr --output DP-0 --brightness 0.8
#xrandr --output DP-3 --brightness 0.8
for SALIDA in $( xrandr | grep -v Screen | cut -d\  -f1 | sort -u | xargs )
do
    xrandr --output ${SALIDA} --brightness $1 2>/dev/null
done
