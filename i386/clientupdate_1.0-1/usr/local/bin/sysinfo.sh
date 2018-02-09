#!/bin/bash

SYSINFO=`head -n 1 /etc/issue | cut -d\\\\ -f 1`
IFS=$'\n'
UPTIME=`uptime`
D_UP=${UPTIME:1}
MYGROUPS=`groups`
DATE=`date`
KERNEL=`uname -a`
CPWD=`pwd`
ME=`whoami`
CPU=`arch`
MODES=`LANG= LC_ALL= LC_MESSAGES=C lscpu | grep op-mode | head -n 1 | cut -d: -f2 | xargs`
SOCKETS=`LANG= LC_ALL= LC_MESSAGES=C lscpu | grep Socket | head -n 1 | cut -d: -f2 | xargs`
NAME=`LANG= LC_ALL= LC_MESSAGES=C lscpu | grep name | head -n 1 | cut -d: -f2 | xargs`
CORES=`LANG= LC_ALL= LC_MESSAGES=C lscpu | grep Core\(s\) | head -n 1 | cut -d: -f2 | xargs`
THREADS=`LANG= LC_ALL= LC_MESSAGES=C lscpu | grep CPU\(s\) | grep -v NUMA | grep -v list | head -n 1 | cut -d: -f2 | xargs`
GPU=`lspci | grep VGA | cut -d: -f 3 | xargs`
MOTHERBOARD=`dmidecode -t2 -u | grep \" | head -n 3 | xargs`
MODEL=`dmidecode -t1 | grep Product\ Name | xargs | cut -d: -f2 | xargs`
MAC=$(cat /sys/class/net/*/address 2>/dev/null | head -n1)
printf "<=== SYSTEM ===>\n"
printf "  Product Name:\t$MODEL\n"
echo "  Distribution:	"$SYSINFO""
printf "  Linux Arch:\t"$CPU"\n"
printf "  Kernel:\t"$KERNEL"\n"
printf "  Uptime:\t"$D_UP"\n"
printf "  Date:\t\t"$DATE"\n"
free -mt | awk '
/Mem/{print "  Memory:\tTotal: " $2 "Mb\tUsed: " $3 "Mb\tFree: " $4 "Mb"}
/Swap/{print "  Swap:\t\tTotal: " $2 "Mb\tUsed: " $3 "Mb\tFree: " $4 "Mb"}'
#cat /proc/cpuinfo | grep "model name\|processor" | awk '
#/processor/{printf "  Processor:\t" $3 " : " }
#/model\ name/{
#i=4
#while(i<=NF){
#	printf $i
#	if(i<NF){
#		printf " "
#	}
#	i++
#}
#printf "\n"
#}'
printf "\n<=== CPU ===>\n"
printf "  CPU Name:\t$NAME\n"
printf "  CPU Arch:\t$MODES\n"
printf "  CPU Sockets:\t$SOCKETS\n"
printf "  CPU Cores:\t$CORES\n"
printf "  CPU Threads:\t$THREADS\n"
printf "\n<= MOTHERBOARD =>\n"
printf "  Model:\t$MOTHERBOARD\n"
printf "\n<=== GPU ===>\n"
printf "  GPU Name:\t$GPU\n"
printf "\n<=== DISK ===>\n"
lsscsi --size | cut -d\  -f3-
printf "\n<=== NETWORK ===>\n"
printf "  Hostname:\t"$HOSTNAME"\n"
printf "  MAC:\t\t"$MAC"\n"
ip -o addr | awk '/inet /{print "  IP (" $2 "):\t" $4}'
/sbin/route -n | awk '/^0.0.0.0/{ printf "  Gateway:\t"$2"\n" }'
cat /etc/resolv.conf | awk '/^nameserver/{ printf "  Name Server:\t" $2 "\n"}'
printf "\n<=== USER ===>\n"
printf "  User:\t\t"$ME" (uid:"$UID")\n"
printf "  Groups:\t"$MYGROUPS"\n"
printf "  Working dir:\t"$CPWD"\n"
printf "  Home dir:\t"$HOME"\n"
