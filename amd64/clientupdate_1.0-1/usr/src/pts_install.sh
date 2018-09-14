#!/bin/bash
cd /tmp
apt-get update
apt-get -y install php5-cli php5-gd php-xml-serializer
apt-get --fix-missing -f install
apt-get -y install php5-cli php5-gd php-xml-serializer
wget http://phoronix-test-suite.com/releases/repo/pts.debian/files/phoronix-test-suite_8.0.1_all.deb
dpkg -i phoronix-test-suite_8.0.1_all.deb
apt-get --fix-missing -f install
#phoronix-test-suite install pts/ffmpeg pts/stream pts/unpack-linux
echo Finished.
