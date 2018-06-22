#!/bin/bash

NVIDIA_GPU=$(lspci | grep VGA | grep NVIDIA | wc -l)

cd "$(dirname "$0")"
if [ -d /usr/lib/nvidia ]; then
    ln -s /usr/lib/libvdpau.so /usr/lib/nvidia/libvdpau.so
fi
apt-get install -y kernel-package 
apt-get install -y ncurses-dev
apt-get install -y libssl-dev 
apt-get install -y git 
apt-get install -y libquvi-dev 
apt-get install -y libx264-dev 
apt-get install -y libmp3lame-dev 
apt-get install -y libjpeg-dev 
apt-get install -y libfribidi-dev 
apt-get install -y libfreetype6-dev 
apt-get install -y libasound2-dev 
apt-get install -y libpulse-dev 
apt-get install -y libxcb1-dev 
apt-get install -y libx11-dev 
apt-get install -y libvdpau-dev 
apt-get install -y libgl1-mesa-dev 
apt-get install -y libxv-dev 
apt-get install -y libva-dev 
apt-get install -y frei0r-plugins-dev 
apt-get install -y libgnutls-dev 
apt-get install -y libgsm1-dev 
apt-get install -y libopencore-amrnb-dev 
apt-get install -y libopencore-amrwb-dev 
apt-get install -y libopenjpeg-dev 
apt-get install -y libopenjp2-7-dev
apt-get install -y librtmp-dev 
apt-get install -y libschroedinger-dev 
apt-get install -y libspeex-dev 
apt-get install -y libtheora-dev 
apt-get install -y libvorbis-dev 
apt-get install -y libvpx-dev 
apt-get install -y libxvidcore-dev 
apt-get install -y libcdio-paranoia-dev 
apt-get install -y libdc1394-22-dev 
apt-get install -y dh-autoreconf 
apt-get install -y fontconfig 
apt-get install -y python-fontconfig 
#apt-get install -y python-fontconfig-dbg 
apt-get install -y nasm 
apt-get install -y yasm 
apt-get install -y libghc-bzlib-dev
apt-get install -y libopencv-dev
apt-get install -y libarchive-dev
apt-get install -y libfdk-aac-dev
apt-get install -y libopus-dev
apt-get install -y libx265-dev 
apt-get install -y libass-dev 
apt-get install -y libssl-dev 
apt-get install -y libxss-dev
apt-get install -y libcaca-dev
apt-get install -y libxrandr-dev
apt-get install -y libxinerama-dev
apt-get install -y libavfilter-dev
apt-get install -y libvulkan-dev
apt-get install -y libegl1-mesa-dev
apt-get install -y mediainfo
apt-get install -y mediainfo-gui
apt-get purge -y texlive-*-doc
clear
rm -rf mpv-build
git clone https://github.com/mpv-player/mpv-build.git
cd mpv-build
echo "--enable-pthreads" >> ffmpeg_options
echo "--enable-nonfree" >> ffmpeg_options
echo "--enable-libass" >> ffmpeg_options
echo "--enable-libfdk-aac" >> ffmpeg_options
echo "--enable-libx265" >> ffmpeg_options
echo "--enable-libopus" >> ffmpeg_options
echo "--enable-openssl" >> ffmpeg_options
echo "--enable-libx264" >> ffmpeg_options
echo "--enable-libmp3lame" >> ffmpeg_options
# echo "--enable-libfdk-aac" >> ffmpeg_options
echo "--enable-nonfree" >> ffmpeg_options
# echo "--enable-memalign-hack" >> ffmpeg_options
echo "--enable-avisynth" >> ffmpeg_options
echo "--enable-libspeex" >> ffmpeg_options
echo "--enable-libtheora" >> ffmpeg_options
echo "--enable-libvorbis" >> ffmpeg_options
echo "--enable-libx264" >> ffmpeg_options
echo "--enable-libxvid" >> ffmpeg_options
echo "--enable-version3" >> ffmpeg_options
echo "--enable-libopencore-amrnb" >> ffmpeg_options
echo "--enable-libopencore-amrwb" >> ffmpeg_options
echo "--enable-runtime-cpudetect" >> ffmpeg_options
echo "--enable-bzlib" >> ffmpeg_options
echo "--enable-libdc1394" >> ffmpeg_options
echo "--enable-libfreetype" >> ffmpeg_options
echo "--enable-frei0r" >> ffmpeg_options
#echo "--enable-gnutls" >> ffmpeg_options
echo "--enable-libgsm" >> ffmpeg_options
echo "--enable-libmp3lame" >> ffmpeg_options
echo "--enable-librtmp" >> ffmpeg_options
# echo "--enable-libopencv" >> ffmpeg_options
echo "--enable-libopenjpeg" >> ffmpeg_options
echo "--enable-libpulse" >> ffmpeg_options
#echo "--enable-libschroedinger" >> ffmpeg_options
echo "--enable-libspeex" >> ffmpeg_options
echo "--enable-libtheora" >> ffmpeg_options
echo "--enable-vaapi" >> ffmpeg_options
echo "--enable-vdpau" >> ffmpeg_options
echo "--enable-libvorbis" >> ffmpeg_options
echo "--enable-libvpx" >> ffmpeg_options
echo "--enable-zlib" >> ffmpeg_options
echo "--enable-gpl" >> ffmpeg_options
echo "--enable-postproc" >> ffmpeg_options
echo "--enable-libcdio" >> ffmpeg_options
# echo "--enable-x11grab" >> ffmpeg_options

# Tweaks for NVIDIA cards
if [ ! "${NVIDIA_GPU}" -eq "0" ]; then
    echo "--enable-cuda" >> ffmpeg_options
    echo "--enable-cuvid" >> ffmpeg_options
    echo "--enable-nvdec" >> ffmpeg_options
fi

git clone https://github.com/georgmartius/vid.stab.git
cd vid.stab
cmake . && make && make install && echo "--enable-libvidstab" >> ../ffmpeg_options
cp -f /usr/local/lib/libvidstab.so* /usr/lib/
cd ..

echo "--disable-debug-build --enable-xv --enable-gl-x11 --enable-vdpau --enable-vdpau-gl-x11 --enable-vaapi --enable-vaapi-x11 --enable-vaapi-glx --enable-caca --enable-gl" >> mpv_options
export CFLAGS="-O3 -march=native -mtune=native -pipe"
export CXXFLAGS=${CFLAGS}
# cuda support was moved to a separate repository, build it. ffnvcodec
# https://github.com/FFmpeg/nv-codec-headers
git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers
make && make install
cd ..
./use-mpv-master
./use-ffmpeg-master
CONCURRENCY_LEVEL=$(getconf _NPROCESSORS_ONLN) ./rebuild -j$(getconf _NPROCESSORS_ONLN)
./install
if [ ! -f /usr/bin/mpv ]; then
    ln -s /usr/local/bin/mpv /usr/bin/mpv
fi
