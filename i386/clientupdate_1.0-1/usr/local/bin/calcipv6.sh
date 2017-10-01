#!/bin/bash
printf "2002:%x%02x:%x%02x::\n" `echo $1 | sed 's/\./ /g'`
