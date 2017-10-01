#!/bin/bash

if [ $# == 0 ]; then
	echo "Too few parameters, please specify host to check."
	exit;
fi;

ESTADO=`ping -c 1 -W 1 $1 | grep "bytes from" | wc -l`;

if [ $ESTADO == 1 ]; then
	NOMBRE=`host $1 2>&1 | grep "does not exist" | wc -l`
	if [ $NOMBRE == 0 ]; then
		NOMBRE=`host $1 2>/dev/null | grep ame | cut -d \  -f 5 | wc -l`;
		if [ $NOMBRE == 0 ]; then
			NOMBRE=`echo $1 | cut -d. -f 1-`;
		else
			NOMBRE=`host $1 2>/dev/null | grep ame | cut -d \  -f 5 | cut -d. -f 1`;
		fi;
	else
		NOMBRE=$1;
	fi;
	echo "PONG from $NOMBRE";
fi;
