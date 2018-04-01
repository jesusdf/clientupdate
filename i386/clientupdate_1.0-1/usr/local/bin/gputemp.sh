#!/bin/bash
DISPLAY=:0.0 nvidia-settings -q gpucoretemp | grep Attribute | cut -d. -f 2 | cut -d: -f 2 | cut -d\  -f 2
