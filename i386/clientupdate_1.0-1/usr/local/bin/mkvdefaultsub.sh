#!/bin/bash
TRACKNUMBER=$( LANG=C mkvinfo -s $2 | head -n 30 | grep subtitle | grep -E "$1" | sort -r | head -n 1 | cut -d: -f1 | cut -d\  -f2 | xargs )
if [[ -z $TRACKNUMBER ]]; then
	echo "Subtitle track '$1' not found in '$2' file."
	exit -1;
else
	echo "$2"
	echo -ne "\tRemoving default track on all subtitles..."
	i=1
	mkvpropedit "$2" --edit track:s$i --set flag-default=0 1>/dev/null 2>&1
	while [[ "$?" -eq 0 ]]; do
		i=$((i+1))
		mkvpropedit "$2" --edit track:s$i --set flag-default=0 1>/dev/null 2>&1
	done
	echo "done."

	echo -ne "\tSetting subtitle track '$1' #$TRACKNUMBER as default... "
	mkvpropedit "$2" --edit track:$TRACKNUMBER --set flag-default=1 1>/dev/null
	echo "done."

	exit 0;
fi
