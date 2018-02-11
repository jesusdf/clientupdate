#!/bin/bash
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys "$1" || gpg --keyserver hkp://pgp.mit.edu --recv-keys "$1" || gpg --keyserver hkp://subkeys.pgp.net --recv-keys "$1"
gpg --export --armor "$1" | apt-key add -
