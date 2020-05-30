#!/bin/bash
if [ "$( cat /etc/environment | grep fcitx | wc -l )" == "0" ]; then
    echo "XMODIFIERS=@im=fcitx" >> /etc/environment
    echo "GTK_IM_MODULE=fcitx" >> /etc/environment
    echo "QT_IM_MODULE=fcitx" >> /etc/environment
fi
apt-get install -y fcitx
apt-get install -y fcitx-mozc
apt-get install -y fcitx-config-gtk
if [ ! -f /etc/xdg/autostart/fcitx.desktop  ]; then
    ln -s /usr/share/applications/fcitx.desktop /etc/xdg/autostart/
fi
echo "Done."
echo "Now add the Mozc input method in fcitx and toggle to it using Control + Space."
