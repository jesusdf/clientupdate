#!/bin/bash

su - `cat /etc/passwd | grep 1000 | cut -d: -f1` -c "x11vnc -safer -nopw -once -display :0.0"
