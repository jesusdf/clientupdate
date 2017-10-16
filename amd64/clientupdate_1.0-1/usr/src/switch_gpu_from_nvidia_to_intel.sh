#!/bin/bash
# Remove nomodeset from /etc/default/grub
# Run update-grub
sudo apt-get update
sudo nvidia-settings --uninstall
sudo apt-get install --reinstall xserver-xorg-video-intel libgl1-mesa-glx libgl1-mesa-dri xserver-xorg-core
sudo dpkg-reconfigure xserver-xorg
sudo rm /usr/lib/xorg/modules/extensions/libglx.so
sudo apt-get --reinstall install xserver-xorg-core
sudo apt-get install --reinstall xserver-xorg-video-intel libgl1-mesa-glx libgl1-mesa-dri xserver-xorg-core
