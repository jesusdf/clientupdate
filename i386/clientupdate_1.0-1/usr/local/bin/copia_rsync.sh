#!/bin/bash
# Copia una carpeta desde otro equipo con rsync sobre ssh, conservando permisos y propietarios.
#
# Uso:     sudo ./copia_rsync.sh root@equipo[:puerto]/carpeta carpeta_destino [opciones de rsync]
# Ejemplo: sudo ./copia_rsync.sh root@10.0.0.20/home/* /home/
#
# - El puerto es opcional: si no se indica, se usa el 22.
# - Hay que lanzarlo como root: solo root puede asignar propietarios en el destino.
#   Con sudo, ssh usa las claves y el known_hosts de root, no los del usuario.
# - Los propietarios se asignan por nombre de usuario/grupo; si el nombre no existe en este equipo, por numero.
# - Como en rsync, si el origen acaba en / se copia el contenido de la carpeta; si no, la carpeta entera dentro del destino.
# - Necesita rsync instalado en los dos equipos.

set -euo pipefail

if [[ $# -lt 2 || ! $1 =~ ^([^@:/]+@[^@:/]+)(:([0-9]*))?(/.*)$ ]]; then
    echo "Uso: sudo $0 root@equipo[:puerto]/carpeta carpeta_destino [opciones de rsync]" >&2
    exit 1
fi
equipo=${BASH_REMATCH[1]}
puerto=${BASH_REMATCH[3]:-22}
carpeta=${BASH_REMATCH[4]}
destino=$2

if [[ $(id -u) -ne 0 ]]; then
    echo "Hay que lanzarlo como root (sudo) para conservar los propietarios." >&2
    exit 1
fi

# -a conserva permisos, propietario, grupo, fechas y enlaces simbolicos; -z comprime en transito
rsync -avz -e "ssh -p $puerto" "${@:3}" "$equipo:$carpeta" "$destino"

