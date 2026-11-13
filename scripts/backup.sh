#!/usr/bin/env bash
set -euo pipefail
umask 027

APP_DIR=/var/www/miproyecto
CONFIG_DIR=/etc/miproyecto
VHOST_FILE=/etc/apache2/sites-available/miproyecto.com.conf
DB_NAME=miproyecto
BACKUP_DIR=/srv/respaldos/local
LOG_DIR=/srv/respaldos/logs
KEEP_LOCAL=4
KEEP_CLOUD=4
RCLONE_DEST=""
RCLONE_CONFIG_FILE=/root/.config/rclone/rclone.conf
[[ -f /etc/miproyecto/backup.conf ]] && source /etc/miproyecto/backup.conf

TIPO=manual
[[ "${1:-}" == --semanal ]] && TIPO=semanal
NOMBRE="miproyecto_$(date +%Y-%m-%d_%H%M%S)_$TIPO"
ARCHIVO="$BACKUP_DIR/$NOMBRE.tar.gz"
RCLONE=(rclone --config "${RCLONE_CONFIG_FILE:-/root/.config/rclone/rclone.conf}" --log-file "$LOG_DIR/rclone.log" --log-level INFO)

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo: sudo $0" >&2; exit 1; }
mkdir -p "$BACKUP_DIR" "$LOG_DIR"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG_DIR/backup.log"; }
trap 'log "ERROR: falló el respaldo $NOMBRE"' ERR
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

log "Inicio del respaldo $NOMBRE"
mariadb-dump --single-transaction --routines --triggers "$DB_NAME" > "$TMP/basedatos.sql"
tar -czf "$ARCHIVO" --exclude="${APP_DIR#/}/.git" -C "$TMP" basedatos.sql -C / "${APP_DIR#/}" "${CONFIG_DIR#/}" "${VHOST_FILE#/}"
(cd "$BACKUP_DIR" && sha256sum "$NOMBRE.tar.gz" > "$NOMBRE.tar.gz.sha256")
log "Respaldo local creado: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))"

ls -1 "$BACKUP_DIR"/miproyecto_*_"$TIPO".tar.gz | sort -r | tail -n +$((KEEP_LOCAL + 1)) | while read -r viejo; do
    rm -f "$viejo" "$viejo.sha256"
    log "Respaldo local antiguo eliminado: $(basename "$viejo")"
done

if [[ -z "$RCLONE_DEST" ]]; then
    log "Aviso: la copia en Backblaze B2 no está configurada"
    exit 0
fi

if "${RCLONE[@]}" copy "$ARCHIVO" "$RCLONE_DEST/" && "${RCLONE[@]}" copy "$ARCHIVO.sha256" "$RCLONE_DEST/"; then
    log "Transferencia a Backblaze B2 correcta: $RCLONE_DEST/$NOMBRE.tar.gz"
else
    log "ERROR: falló la transferencia a Backblaze B2 (ver $LOG_DIR/rclone.log)"
    exit 2
fi

"${RCLONE[@]}" lsf --files-only --include "miproyecto_*_$TIPO.tar.gz" "$RCLONE_DEST/" | sort -r | tail -n +$((KEEP_CLOUD + 1)) | while read -r viejo; do
    "${RCLONE[@]}" deletefile "$RCLONE_DEST/$viejo"
    "${RCLONE[@]}" deletefile "$RCLONE_DEST/$viejo.sha256" || true
    log "Respaldo antiguo eliminado de Backblaze B2: $viejo"
done
log "Respaldo $NOMBRE finalizado"
