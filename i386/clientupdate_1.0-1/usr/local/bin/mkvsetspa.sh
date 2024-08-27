#!/bin/bash
find . -type f -name \*.mkv -exec mkvdefaultsub.sh spa "{}" \;
