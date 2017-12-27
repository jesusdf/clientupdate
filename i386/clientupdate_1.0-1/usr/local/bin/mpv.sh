#!/bin/bash

NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)
CRYSTALHD=$(lspci | grep BCM | grep Crystal\ HD | wc -l)
MPV_HWDEC=$(/usr/local/bin/mpv -hwdec=help | grep -v copy)
NVDEC=$(echo ${MPV_HWDEC} | grep nvdec | wc -l)
VAAPI=$(echo ${MPV_HWDEC} | grep vaapi | wc -l)
VDPAU=$(echo ${MPV_HWDEC} | grep vdpau | wc -l)

if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
    if [ ! "${NVDEC}" -eq "0" ]; then
        HWDEC=nvdec
    else
        HWDEC=vaapi
    fi
else
    if [ ! "${CRYSTALHD}" -eq "0" ]; then
	# Usually old computers with Crystal HD only support OPENGL 1.4
        HWDEC=crystalhd
	export MESA_GL_VERSION_OVERRIDE=2.1
    else
        if [ ! "${VAAPI}" -eq "0" ]; then
            HWDEC=vaapi
        else
            if [ ! "${VDPAU}" -eq "0" ]; then
                HWDEC=vdpau
            else
                HWDEC=auto
            fi
        fi
    fi
fi

if [ "$1"!="" ]; then
    /usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=${HWDEC} -vo gpu,opengl,xv -ao pulse --audio-channels 6 -fs "$1"
fi

IS_DEFAULT=$(/usr/bin/xdg-mime query default video/x-matroska)

if [ "${IS_DEFAULT}"!="mpv-custom.desktop" ]; then
    # Set as default application
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-matroska
    /usr/bin/xdg-mime default mpv-custom.desktop application/x-matroska
    /usr/bin/xdg-mime default mpv-custom.desktop video/mp4
    /usr/bin/xdg-mime default mpv-custom.desktop application/x-extension-mp4
    /usr/bin/xdg-mime default mpv-custom.desktop video/mp4v-es
    /usr/bin/xdg-mime default mpv-custom.desktop video/mpeg
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-mpeg
    /usr/bin/xdg-mime default mpv-custom.desktop video/msvideo
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-msvideo
    /usr/bin/xdg-mime default mpv-custom.desktop video/quicktime
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-ms-wmv
    /usr/bin/xdg-mime default mpv-custom.desktop video/webm
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-avi
    /usr/bin/xdg-mime default mpv-custom.desktop video/x-flv
fi

