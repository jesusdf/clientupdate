#!/bin/bash

NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)
CRYSTALHD=$(lspci | grep BCM | grep Crystal\ HD | wc -l)

if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
    HWDEC=nvdec
else
    if [ ! "${CRYSTALHD}" -eq "0" ]; then
	# Usually old computers with Crystal HD only support OPENGL 1.4
        HWDEC=crystalhd
	export MESA_GL_VERSION_OVERRIDE=2.1
    else
        HWDEC=vaapi
    fi
fi

/usr/bin/nice --adjustment=-10 /usr/local/bin/mpv --quiet -hwdec=${HWDEC} -vo gpu,opengl,xv -ao pulse --audio-channels 6 -fs "$1"

