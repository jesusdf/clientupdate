#!/bin/bash
PARAMS=$@

if [[ -z $PARAMS ]]; then
  echo "The file or folder parameter is missing, nothing to process."
  echo "Usage examples:"
  echo -e "\t$0 /my/folder"
  echo -e "\t$0 file.mkv"
  exit -1
fi

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR=$(dirname "$PARAMS")
FILE=$(basename "$PARAMS")

cd "$DIR"
CURDIR=$(pwd)

if [ -d "$FILE" ]; then
  # Directory
  find "$CURDIR" -type f -name \*.mkv -exec ${SCRIPTDIR}/mkvdef.py -y -a jp -s es-ES "{}" \;
  exit 0
fi

# Single file
${SCRIPTDIR}/mkvdef.py -y -a jp -s es-ES "$FILE"

