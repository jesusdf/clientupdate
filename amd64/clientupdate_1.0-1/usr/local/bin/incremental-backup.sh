#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

if [ $# -lt 2 ]; then
  echo 1>&2 "$0: Missing arguments: $0 source destination"
  exit 2
elif [ $# -gt 2 ]; then
  echo 1>&2 "$0: Too many arguments: $0 source destination"
  exit 2
fi

readonly SOURCE_DIR=$( realpath "$1" )
readonly BACKUP_DIR=$( realpath "$2" )
readonly DATETIME="$(date '+%Y-%m-%d_%H.%M.%S')"
readonly BACKUP_PATH="${BACKUP_DIR}/${DATETIME}"
readonly LATEST_LINK="${BACKUP_DIR}/latest"

mkdir -p "${BACKUP_DIR}"

rsync -av --delete \
  "${SOURCE_DIR}/" \
  --link-dest "${LATEST_LINK}" \
  --exclude=".cache" \
  "${BACKUP_PATH}"

rm -rf "${LATEST_LINK}"
ln -s "${BACKUP_PATH}" "${LATEST_LINK}"


