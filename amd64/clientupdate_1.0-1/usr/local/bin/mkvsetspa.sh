#!/bin/bash
PARAMS=$@

if [[ -z $PARAMS ]]; then
  echo "The file or folder parameter is missing, nothing to process."
  echo "Usage examples:"
  echo -e "\t$0 /my/folder"
  echo -e "\t$0 file.mkv"
  exit -1
fi

DIR=$(dirname "$PARAMS")
FILE=$(basename "$PARAMS")
LANG=": es[-][eE][sS]|: es|: spa"

cd "$DIR"
CURDIR=$(pwd)

if [ -d "$FILE" ]; then
  # Directory
  find "$CURDIR" -type f -name \*.mkv -exec "$0" "{}" \;
  exit 0
fi

# Single file
mkvdefaultsub.sh "$LANG" "$FILE"
