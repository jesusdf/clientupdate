#!/usr/bin/env bash

if [ ! -f /sys/class/power_supply/BAT?/capacity ]; then
  echo "No hay una batería conectada."
  exit 0;
fi

level=$(cat /sys/class/power_supply/BAT?/capacity)
status=$(cat /sys/class/power_supply/BAT?/status)
logonuser=`cat /etc/passwd | grep 1000 | cut -d: -f1`

# Exit if not discharging
if [ "${status}" != "Discharging" ]; then
  echo "La batería no se está descargando."
  exit 0;
fi

notify_action_percentage=15
critical_action_percentage=9

if [ "${level}" -le ${critical_action_percentage} ]; then
  echo "Batería en nivel crítico, apagando...";
  su ${logonuser} -c "DISPLAY=:0 /usr/bin/notify-send -i notification-power-disconnected -t 60 -u critical 'Batería en estado crítico, apagando el sistema para proteger los datos...'";
  sync;
  sleep 15;
  sync;
  /sbin/poweroff;
else
	if [ "${level}" -le ${notify_action_percentage} ]; then
	  echo "Batería en bajo nivel de carga, notificando al usuario...";
	  su ${logonuser} -c "DISPLAY=:0 /usr/bin/notify-send -i notification-battery-low -u normal 'Se está agotando la batería, conecte el cargador o el equipo se apagará.'";
	fi
fi

exit 0;

