#!/bin/bash
#/usr/bin/nice --adjustment=-10 /usr/local/bin/mplayer --quiet -vo xv -ao alsa -fs -dr -framedrop -hardframedrop "$1"
#/usr/bin/nice --adjustment=-10 /usr/local/bin/mplayer --quiet -vo gl_nosw -ao alsa -fs -dr -framedrop -hardframedrop "$1"
#/usr/bin/nice --adjustment=-10 /usr/local/bin/mplayer --quiet -vo vdpau -ao alsa -fs -dr -framedrop -hardframedrop "$1"
#/usr/bin/nice --adjustment=-10 /usr/bin/vlc -f --video-on-top --sub-autodetect-file --play-and-exit --osd --key-jump-extrashort=Left --key-jump+extrashort=Right --key-jump-medium=Down --key-jump+medium=Up --key-leave-fullscreen=q --key-audio-track=Ctrl-j --key-subtitle-track=Ctrl-3 --key-position=o --key-quit=Esc --quiet --overlay "$1"
#/usr/bin/nice --adjustment=-10 /usr/bin/xterm -e '/usr/local/bin/mpv --quiet -hwdec=vaapi -vo vaapi,xv,opengl-hq,opengl -ao alsa -fs "$1"'

#/usr/local/bin/mpv --quiet -hwdec=vaapi -vo vaapi,xv,opengl-hq,opengl -ao pulse -fs "$1"

#/usr/local/bin/mpv --quiet -vo opengl-hq,opengl -ao alsa -fs "$1"
#/usr/local/bin/mpv --quiet -hwdec=vaapi-copy -vo xv,opengl-hq,opengl -ao alsa -fs "$1"
#/usr/local/bin/mpv --quiet -hwdec=vaapi-copy -vo opengl-hq,opengl -ao alsa -fs "$1"

#/usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=vdpau -vo vdpau -ao pulse -fs "$1"
#/usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=vaapi -vo vaapi,opengl-hq,opengl,xv -ao pulse -fs "$1"

# Forzar 6 canales de audio
#/usr/bin/nice --adjustment=-10 /usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=vdpau -vo vdpau -ao alsa --audio-channels 6 -fs "$1"
/usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=vaapi -vo vaapi,opengl,xv -ao pulse --audio-channels 6 -fs "$1"
#/usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=vaapi -vo opengl:scale=ewa_lanczossharp,vaapi,xv -ao pulse --audio-channels 6 -fs "$1"
#/usr/local/bin/mpv --quiet -hwdec=vdpau -vo vdpau -ao pulse --audio-channels 6 -fs "$1"

#/usr/local/bin/mpv --quiet -hwdec=vaapi-copy -vo xv,opengl-hq,opengl -ao pulse --audio-channels 6 -fs "$1"

#/usr/local/bin/mpv --quiet -vo opengl-hq,opengl -ao pulse --audio-channels 6 -fs "$1"
