#!/usr/bin/env bash
# =============================================================================
#  info_sistema.sh — Estado y recursos del servidor (Parte 1).
#  No necesita root:   bash setup/info_sistema.sh
# =============================================================================
source "$(dirname "$0")/lib.sh"
trap - ERR
set +e

titulo "Equipo"
echo "Nombre del equipo : $(hostname)  (FQDN: $(hostname -f 2>/dev/null))"
echo "Sistema operativo : $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Kernel            : $(uname -r) ($(uname -m))"
echo "Tiempo encendido  : $(uptime -p)"
echo "Fecha / zona      : $(date '+%Y-%m-%d %H:%M:%S %Z')  ($(timedatectl show -p Timezone --value 2>/dev/null))"
echo "Usuarios conectados: $(who | wc -l)"

titulo "Red"
ip -brief address show | grep -v '^lo'
echo "Puerta de enlace  : $(ip route show default | awk '{print $3; exit}')"
echo "DNS               : $(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' | xargs)"
if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then ok "Conectividad IP (ping 8.8.8.8)"; else error "Sin conectividad IP"; fi
if getent hosts debian.org > /dev/null 2>&1; then ok "Resolución DNS (debian.org)"; else error "Falla la resolución DNS"; fi
IP_DOMINIO=$(getent ahostsv4 "$DOMINIO" 2>/dev/null | awk '{print $1; exit}')
if [[ "$IP_DOMINIO" == 127.* || " $(hostname -I) " == *" $IP_DOMINIO "* ]] && [[ -n "$IP_DOMINIO" ]]; then
    ok "$DOMINIO -> $IP_DOMINIO (este servidor)"
else
    aviso "$DOMINIO resuelve a ${IP_DOMINIO:-nada} (no es este servidor: falta la entrada en /etc/hosts)"
fi

titulo "CPU y memoria"
echo "CPU               : $(lscpu | awk -F: '/Model name|Nombre del modelo/ {gsub(/^ +/,"",$2); print $2; exit}') — $(nproc) núcleo(s)"
echo "Carga (1/5/15 min): $(cut -d' ' -f1-3 /proc/loadavg)"
free -h

titulo "Disco"
df -h -x tmpfs -x devtmpfs -x overlay
echo
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS 2>/dev/null || lsblk

titulo "Servicios"
for s in ssh apache2 mariadb cron; do
    printf '  %-9s activo: %-9s inicio automático: %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null)" "$(systemctl is-enabled "$s" 2>/dev/null)"
done
fallidos=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if [[ $fallidos -eq 0 ]]; then ok "No hay servicios en estado 'failed'"; else aviso "$fallidos servicio(s) fallidos:"; systemctl --failed --no-legend; fi

titulo "Puertos en escucha"
ss -tlnp 2>/dev/null | awk 'NR==1 || /:22 |:80 |:443 |:3306 |:3307 /'

titulo "Actualizaciones pendientes"
pend=$(apt list --upgradable 2>/dev/null | grep -vc '^Listando\|^Listing')
if [[ $pend -eq 0 ]]; then ok "Sistema actualizado"; else aviso "$pend paquete(s) para actualizar (sudo apt update && sudo apt full-upgrade)"; fi

titulo "Estructura de directorios"
for d in /srv/administracion /srv/proyectos /srv/compartido "$RESPALDOS_DIR" "$RESPALDOS_DIR"/local "$RESPALDOS_DIR"/logs "$APP_DIR" "$CONFIG_DIR" "$LOG_APP_DIR"; do
    if [[ -e "$d" ]]; then stat -c '  %A  %U:%G  %n' "$d"; else echo "  (no existe)  $d"; fi
done
