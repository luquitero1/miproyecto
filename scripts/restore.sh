#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/miproyecto
DB_NAME=miproyecto
BACKUP_DIR=/srv/respaldos/local
LOG_DIR=/srv/respaldos/logs
RESTORE_DIR=/srv/respaldos/restauracion
RCLONE_DEST=""
RCLONE_CONFIG_FILE=/root/.config/rclone/rclone.conf
[[ -f /etc/miproyecto/backup.conf ]] && source /etc/miproyecto/backup.conf

ORIGEN=local
LISTAR=0
SELECCION=ultimo
for arg in "$@"; do
    case "$arg" in
        --nube) ORIGEN=nube ;;
        --listar) LISTAR=1 ;;
        *) SELECCION=$(basename "$arg") ;;
    esac
done
RCLONE=(rclone --config "${RCLONE_CONFIG_FILE:-/root/.config/rclone/rclone.conf}")

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo: sudo $0" >&2; exit 1; }
mkdir -p "$LOG_DIR" "$RESTORE_DIR"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG_DIR/restore.log"; }
trap 'log "ERROR: falló la restauración"' ERR

listar() {
    if [[ $ORIGEN == nube ]]; then
        "${RCLONE[@]}" lsf --files-only --include 'miproyecto_*.tar.gz' "$RCLONE_DEST/"
    else
        find "$BACKUP_DIR" -maxdepth 1 -name 'miproyecto_*.tar.gz' -printf '%f\n'
    fi | sort
}

if [[ $LISTAR -eq 1 ]]; then
    listar
    exit 0
fi

[[ $SELECCION == ultimo ]] && SELECCION=$(listar | tail -n 1)
[[ $SELECCION == *.tar.gz ]] || SELECCION="$SELECCION.tar.gz"

if [[ $ORIGEN == nube ]]; then
    log "Descargando $SELECCION desde $RCLONE_DEST"
    "${RCLONE[@]}" copy "$RCLONE_DEST/$SELECCION" "$RESTORE_DIR/"
    "${RCLONE[@]}" copy "$RCLONE_DEST/$SELECCION.sha256" "$RESTORE_DIR/"
    ARCHIVO="$RESTORE_DIR/$SELECCION"
else
    ARCHIVO="$BACKUP_DIR/$SELECCION"
fi
(cd "$(dirname "$ARCHIVO")" && sha256sum --check "$SELECCION.sha256")

read -r -p "Se reemplazarán la base de datos y los archivos de la aplicación con $SELECCION. Escribí SI para continuar: " respuesta
[[ $respuesta == SI || $respuesta == si ]] || exit 0

EXTRAIDO="$RESTORE_DIR/${SELECCION%.tar.gz}"
rm -rf "$EXTRAIDO"
mkdir -p "$EXTRAIDO"
tar -xzf "$ARCHIVO" -C "$EXTRAIDO"
mariadb "$DB_NAME" < "$EXTRAIDO/basedatos.sql"
rsync -a --delete --exclude=.git/ "$EXTRAIDO/${APP_DIR#/}/" "$APP_DIR/"
log "Restauración completada desde $ORIGEN: $SELECCION ($(mariadb -N -e "SELECT COUNT(*) FROM $DB_NAME.equipos") equipos)"
