#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/miproyecto
LOG=/var/log/miproyecto/deploy.log

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo: sudo $0" >&2; exit 1; }
mkdir -p "$(dirname "$LOG")"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
trap 'log "ERROR: el despliegue falló"' ERR

cd "$APP_DIR"
log "Inicio del despliegue. Versión actual: $(git log -1 --format='%h %s')"
git fetch origin main
git reset --hard origin/main

chown -R root:desarrolladores "$APP_DIR"
chmod -R g+rwX,o+rX,o-w "$APP_DIR"
find "$APP_DIR" -type d -exec chmod g+s {} +
chown -R root:root "$APP_DIR/.git"
chmod -R go-w "$APP_DIR/.git"

systemctl reload apache2
log "Despliegue finalizado. Versión desplegada: $(git log -1 --format='%h %s')"
