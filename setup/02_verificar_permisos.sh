#!/usr/bin/env bash
set -euo pipefail

USUARIOS=(ana carla elena)
RECURSOS=(/srv/administracion /srv/proyectos /srv/respaldos/local /srv/compartido
          /var/www/miproyecto/public /etc/miproyecto/config.php /home/carla /etc/shadow)

printf '%-30s' "R = lectura, W = escritura"
printf '%-8s' "${USUARIOS[@]}"
echo
for ruta in "${RECURSOS[@]}"; do
    printf '%-30s' "$ruta"
    for usuario in "${USUARIOS[@]}"; do
        permiso=""
        runuser -u "$usuario" -- test -r "$ruta" && permiso+=R || permiso+=-
        runuser -u "$usuario" -- test -w "$ruta" && permiso+=W || permiso+=-
        printf '%-8s' "$permiso"
    done
    echo
done

for usuario in "${USUARIOS[@]}"; do
    sudo -l -U "$usuario"
done
