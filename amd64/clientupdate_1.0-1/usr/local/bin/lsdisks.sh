#!/bin/bash
# note: inspired by Peter
#
# *UPDATE 1* now we're no longer parsing ls output
# *UPDATE 2* now we're using an array instead of the <<< operator, which on its
# part insists on a writable /tmp directory: 
# restricted environments with read-only access often won't allow you that

# save original IFS
OLDIFS="$IFS"

for i in /sys/block/sd*; do 
 readlink $i |
 sed 's^\.\./devices^/sys/devices^ ;
      s^/host[0-9]\{1,2\}/target^ ^ ;
      s^/[0-9]\{1,2\}\(:[0-9]\)\{3\}/block/^ ^' \
 \
  |
  while IFS=' ' read Path HostFull ID
  do

     # OLD line: left in for reasons of readability 
     # IFS=: read HostMain HostMid HostSub <<< "$HostFull"

     # NEW lines: will now also work without a hitch on r/o environments
     IFS=: h=($HostFull)
     HostMain=${h[0]}; HostMid=${h[1]}; HostSub=${h[2]}

     if echo $Path | grep -q '/usb[0-9]*/'; then
       echo "(Device $ID is not an ATA device, but a USB device [e. g. a pen drive])"
     else
       echo $ID: ata$(< "$Path/host$HostMain/scsi_host/host$HostMain/unique_id").$HostMid$HostSub
     fi

  done

done

# restore original IFS
IFS="$OLDIFS"
