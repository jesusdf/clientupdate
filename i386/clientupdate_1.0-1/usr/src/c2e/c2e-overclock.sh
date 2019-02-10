#!/bin/bash

# c2e-overclock v0.5.5 by haarp (main.haarp ÄT gmail DÖT com)
# License: Free to use, modify and distribute anywhere for non-commercial use
# as long as the author is credited. Permission is required for commercial use.
# If you modify this, please let the author know so he can improve it.

# TODO: more sanity checks and strip 0x on payload if present

# Uses the following MSRs:
# FLEX_RATIO (0x194)      controls maximum FID/VID on Extreme/ES CPUs
# IA32_PERF_STATUS (0x198)   shows min, max, current FID/VID
# IA32_PERF_CTL (0x199)      requests a new FID/VID
# IA32_CLOCK_MODULATION (0x19A)   shows/controls clock modulation

# default (X9100): 266x   11.5 @ 1.1875V - 4B26
# undervolt:      11.5 @ 1.0500V - 4B1B !! may need more voltage
# overclock 1:      12.5 @ 1.1875V - 4C26 (may need clockmod)
# overclock 2:      13.0 @ 1.2125V - 0D28 (needs clockmod) !! may need more voltage
# overclock 3:      13.5 @ 1.2625V - 4D2C (overload!)

enableoc() {
   if [[ $oldgovernor && ! $(echo $payload | cut -b 1-2) = $(echo $oldpayload | cut -b 1-2) ]]; then
      echo "New clockspeed differs, disabling CPU frequency scaling."
      for i in $cpulist; do
         echo performance >/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
      done
      changedgovernor=1
   fi

   echo "Switching CPU to 0x$payload."
   setclock $payload
}
disableoc() {
   echo "Restoring CPU to 0x$oldpayload."
   setclock $oldpayload

   if [[ $changedgovernor ]]; then
      echo "Restoring CPU governor to $oldgovernor."
      for i in $cpulist; do
         echo $oldgovernor >/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
      done
   fi
}

setclock() {
   for i in $cpulist; do
      wrmsr -p$i 0x194 0x1$1 #change maximum fid/vid
      wrmsr -p$i 0x199 0x$1 #apply new fid/vid
   done
}
clockmod() {
   for i in $cpulist; do
      wrmsr -p$i 0x19A 0x00
   done
}

loadchecks() {
   [[ $(id -u) = "0" ]] || { echo "Not running as root, aborting!"; exit 1; }
   test -c /dev/cpu/0/msr || {  echo "msr module not loaded, aborting!"; exit 1; }
   which wrmsr &>/dev/null || { echo "Could not find wrmsr, aborting!"; exit 1; }
   which rdmsr &>/dev/null || { echo "Could not find rdmsr, aborting!"; exit 1; }

   cpulist=$(grep processor /proc/cpuinfo | awk '{print $3}')
   oldpayload=$(rdmsr -0 0x198 | cut -b 5-8)
   test -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor && \
      oldgovernor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

}

calcclock() {
   multprefix=$(( 0x$(echo $payload | cut -b 2) ))
   if [[ $(echo $payload | cut -b 1) = 4 ]]; then multsuffix=".5"; else multsuffix=".0"; fi
   multi=$(echo -n "$multprefix$multsuffix")
   voltagem=$(echo "scale=3; 0.7125 + $((0x$(echo $payload | cut -b 3-4) ))*0.0125" | bc)
   voltaged=$(echo "scale=3; 0.8250 + $((0x$(echo $payload | cut -b 3-4) ))*0.0125" | bc)
}

usage() {
   echo "Overclock Intel Core 2 Extreme/ES CPUs or undervolt any Core 2 CPU"
   echo "USE AT YOUR OWN RISK! VERIFY YOUR SETTINGS OR SYSTEM STABILITY MIGHT SUFFER!"
   echo "OC doesnt work with programs that interfere with CPU freq scaling or write MSRs"
   echo "(Linux-PHC, Cpufrequtils, Cpudyn, Powernowd, cpufreqd, cpufreq-applet, etc.)"

   echo -e "\nUsage: $(basename "$0") -p XXXX [-c|-y|-h]"
   echo "Example: '$(basename "$0") -p 4b26 -c' -> x11.5, 1.1875V, disable clockmod"

   echo -e "\n-p XXXX   FID/VID selection, uses 4 hex digits, right->left:"
   echo "   Digit 0-1 = VID      -> U(in V) = 0.7125 + VID*0.0125   (mobile CPUs)"
   echo "                           U(in V) = 0.8250 + VID*0.0125   (desktop CPUs)"
   echo "   Digit 2   = FID      -> Multiplier = FID"
   echo "   Digit 3   = Half-FID -> +0.5 to Multi = 4; +0 to Multi = 0"
   echo "-c   Disable Clock Modulation"
   echo "   Clockmod periodically checks power consumption on some laptops and"
   echo "   engages if it deems it too high (slows down CPU in 12.5% increments)"
   echo "   Disabling this is DANGEROUS and might OVERLOAD the power supply!"
   echo "-y   Assume yes at prompt"
   echo "-h   This help"
}

while getopts ":cyhp:" opt; do
   case $opt in
      p) payload=$OPTARG;;
      c) c=1;;
      y) y=1;;
      h) usage; exit;;
      \?) echo -e "Invalid option: -$OPTARG\nUse -h for help."; exit 1;;
      :) echo -e "Option -$OPTARG requires an argument\nUse -h for help"; exit 1;;
   esac
done
if [[ ! ${#payload} = 4 ]]; then echo -e "No or invalid FID/VID supplied\nUse -h for help"; exit 1; fi

loadchecks

if [[ ! $y ]]; then
   calcclock
        read -p "Would switch CPU to x$multi @ ${voltagem}V/${voltaged}V (mobile/desktop) (0x$payload). Continue? [y/n] " reply
        if [[ ! $reply = [yY] && ! $reply = [yY][eE][sS] ]]; then echo "Aborting!"; exit; fi
fi

trap "disableoc; exit 0" SIGHUP SIGINT SIGTERM
enableoc

#enter infinite loop until terminated
if [[ $c ]]; then
   echo "Forcing clock modulation..."
   while true; do clockmod; sleep 0.25; done
else
   while true; do sleep 0.25; done  #trap cant interrupt sleep, so use very short sleep
fi
