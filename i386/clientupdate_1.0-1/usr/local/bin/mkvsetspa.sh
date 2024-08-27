#!/bin/bash
find . -type f -name \*.mkv -exec mkvdefaultsub.sh ": es[-][eE][sS]|: es|: spa" "{}" \;
