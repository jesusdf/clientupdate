#!/bin/bash

cd /usr/share/alsa/alsa.conf.d
echo >a52.conf "pcm.a52 {"
echo >>a52.conf "  @args [CARD]"
echo >>a52.conf "  @args.CARD {"
echo >>a52.conf "    type string"
echo >>a52.conf "  }"
echo >>a52.conf "  type rate"
echo >>a52.conf "  slave {"
echo >>a52.conf "    pcm {"
echo >>a52.conf "      type a52"
echo >>a52.conf "      bitrate 448"
echo >>a52.conf "      channels 6"
echo >>a52.conf "      card \$CARD"
echo >>a52.conf "    }"
echo >>a52.conf "  rate 48000 #required somehow, otherwise nothing happens in PulseAudio"
echo >>a52.conf "  }"
echo >>a52.conf "}"
sudo apt-get install libavresample-dev
sudo apt-get build-dep libasound2-plugins
sudo apt-get install libavcodec-dev libavformat-dev
mkdir /tmp/a52
cd /tmp/a52
apt-get source libasound2-plugins
cd alsa-plugins-*
./configure
libtoolize --force --copy && aclocal && autoconf && automake --add-missing && make
cd a52/.libs
sudo cp libasound_module_pcm_a52.la libasound_module_pcm_a52.so /usr/lib/alsa-lib/
sudo cp libasound_module_pcm_a52.so /usr/lib/`uname -i`-linux-gnu/alsa-lib/
sudo alsa reload
killall pulseaudio

