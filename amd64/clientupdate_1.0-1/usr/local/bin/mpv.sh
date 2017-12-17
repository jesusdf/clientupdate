#!/bin/bash

NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)
CRYSTALHD=$(lspci | grep BCM | grep Crystal\ HD | wc -l)
NVDEC=$(mpv -hwdec=help | grep nvdec | wc -l)
VAAPI=$(mpv -hwdec=help | grep vaapi | wc -l)
VDPAU=$(mpv -hwdec=help | grep vdpau | wc -l)

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
	export MESA_GL_VERSION_OVERRIDE=2.0
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

/usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=${HWDEC} -vo gpu,opengl,xv -ao pulse --audio-channels 6 -fs "$1"

