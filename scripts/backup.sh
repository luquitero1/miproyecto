#!/usr/bin/env bash
# =============================================================================
#  backup.sh — Respaldo de miproyecto.com (archivos + base de datos)
#              con copia local y copia en la nube (Backblaze B2 vía Rclone).
#
#  Uso:
#    sudo backup.sh                 respaldo manual (local + nube)
#    sudo backup.sh --semanal       respaldo programado (lo usa crontab)
#    sudo backup.sh --solo-local    no sube a la nube
#
#  Crontab (root):   0 0 * * 6 /usr/local/bin/backup.sh --semanal
#
#  Cada respaldo es un único archivo:
#     /srv/respaldos/local/miproyecto_AAAA-MM-DD_HHMMSS_<tipo>.tar.gz
#  que contiene:
#     basedatos.sql                         volcado completo de la base
#     INFO.txt                              datos del respaldo
#     var/www/miproyecto/...                archivos de la aplicación
#     etc/miproyecto/...                    configuración (credenciales)
#     etc/apache2/sites-available/...       VirtualHost
#  junto con su suma de verificación .sha256
#
#  Se conservan los últimos KEEP_LOCAL respaldos de cada tipo en el disco y los
#  últimos KEEP_CLOUD de cada tipo en Backblaze B2 (por defecto 4 = 4 semanas).
#
#  Códigos de salida: 0 = OK · 1 = falló el respaldo local · 2 = falló la nube
# =============================================================================
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umask 027

# --- Configuración por defecto (se puede cambiar en /etc/miproyecto/backup.conf) ---
APP_DIR="/var/www/miproyecto"
CONFIG_DIR="/etc/miproyecto"
VHOST_FILE="/etc/apache2/sites-available/miproyecto.com.conf"
DB_NAME="miproyecto"
BACKUP_DIR="/srv/respaldos/local"
LOG_DIR="/srv/respaldos/logs"
BACKUP_GROUP="respaldos"
PREFIX="miproyecto"
KEEP_LOCAL=4
KEEP_CLOUD=4
RCLONE_DEST=""            # ej.: b2:miproyecto-respaldos-lucas/miproyecto  (vacío = no sube)
RCLONE_CONFIG_FILE=""     # vacío = el de root (/root/.config/rclone/rclone.conf)
DB_DUMP_OPTS=()           # opciones extra para mariadb-dump (ej. --socket=...)

CONF_FILE="${BACKUP_CONF:-/etc/miproyecto/backup.conf}"
if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
fi

# --- Argumentos ---------------------------------------------------------------
TIPO="manual"
SUBIR_NUBE=1
for arg in "$@"; do
    case "$arg" in
        --semanal)      TIPO="semanal" ;;
        --tipo=*)       TIPO="${arg#--tipo=}" ;;
        --solo-local)   SUBIR_NUBE=0 ;;
        -h|--help)      sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Opción desconocida: $arg (ver --help)" >&2; exit 1 ;;
    esac
done
[[ "$TIPO" =~ ^[a-z0-9-]+$ ]] || { echo "Tipo inválido: $TIPO" >&2; exit 1; }

LOG_FILE="$LOG_DIR/backup.log"
RCLONE_LOG="$LOG_DIR/rclone.log"
TS="$(date '+%Y-%m-%d_%H%M%S')"
NOMBRE="${PREFIX}_${TS}_${TIPO}"
ARCHIVO="$BACKUP_DIR/$NOMBRE.tar.gz"
# Dos ejecuciones en el mismo segundo no deben pisarse
while [[ -e "$ARCHIVO" ]]; do
    sleep 1
    TS="$(date '+%Y-%m-%d_%H%M%S')"; NOMBRE="${PREFIX}_${TS}_${TIPO}"; ARCHIVO="$BACKUP_DIR/$NOMBRE.tar.gz"
done
INICIO=$SECONDS

# --- Funciones auxiliares -----------------------------------------------------
log() {
    local nivel="$1"; shift
    local linea
    linea="$(date '+%Y-%m-%d %H:%M:%S') [$nivel] $*"
    echo "$linea" | tee -a "$LOG_FILE"
    logger -t miproyecto-backup -- "[$nivel] $*" 2>/dev/null || true
}

TMP=""
limpiar() { [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"; }
trap limpiar EXIT
trap 'log ERROR "Fallo en la línea $LINENO (comando: $BASH_COMMAND)"; log ERROR "===== RESPALDO $NOMBRE FALLIDO ====="; rm -f "$ARCHIVO" "$ARCHIVO.part" "$ARCHIVO.sha256"; exit 1' ERR

# Aplica la política de retención sobre una lista de nombres (ordenados por fecha).
# Imprime los que sobran (los más antiguos) dejando los últimos $1.
sobrantes() { sort -r | tail -n +"$(( $1 + 1 ))"; }

rclone_cmd() {
    local args=(--log-file "$RCLONE_LOG" --log-level INFO)
    [[ -n "$RCLONE_CONFIG_FILE" ]] && args+=(--config "$RCLONE_CONFIG_FILE")
    rclone "${args[@]}" "$@"
}

# --- Comprobaciones previas ---------------------------------------------------
if [[ $EUID -ne 0 && "${BACKUP_SIN_ROOT:-0}" != 1 ]]; then
    echo "Este script debe ejecutarse como root:  sudo $0" >&2
    exit 1
fi
mkdir -p "$BACKUP_DIR" "$LOG_DIR"
touch "$LOG_FILE"

exec 9>"$BACKUP_DIR/.backup.lock"
flock -n 9 || { echo "Ya hay un respaldo en ejecución." >&2; exit 1; }

DUMP_BIN=$(command -v mariadb-dump || command -v mysqldump) || { log ERROR "No se encontró mariadb-dump/mysqldump"; exit 1; }

log INFO "===== INICIO DEL RESPALDO $NOMBRE (tipo: $TIPO) ====="

TMP=$(mktemp -d "$BACKUP_DIR/.tmp.XXXXXX")

# --- 1. Base de datos ---------------------------------------------------------
log INFO "Volcando la base de datos '$DB_NAME'..."
"$DUMP_BIN" "${DB_DUMP_OPTS[@]}" --single-transaction --quick --routines --triggers --events \
    --default-character-set=utf8mb4 "$DB_NAME" > "$TMP/basedatos.sql"
TABLAS=$(grep -c '^CREATE TABLE' "$TMP/basedatos.sql" || true)
log INFO "Base de datos volcada: $TABLAS tabla(s), $(du -h "$TMP/basedatos.sql" | cut -f1)."

# --- 2. Información del respaldo ----------------------------------------------
{
    echo "Respaldo:     $NOMBRE"
    echo "Tipo:         $TIPO"
    echo "Fecha:        $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Servidor:     $(hostname)"
    echo "Base:         $DB_NAME ($TABLAS tablas)"
    echo "Aplicación:   $APP_DIR"
    if [[ -d "$APP_DIR/.git" ]]; then
        echo "Commit Git:   $(git -c safe.directory="$APP_DIR" -C "$APP_DIR" log -1 --format='%h %s' 2>/dev/null || echo '?')"
    fi
} > "$TMP/INFO.txt"

# --- 3. Archivo comprimido con todo -------------------------------------------
RUTAS=()
for ruta in "$APP_DIR" "$CONFIG_DIR" "$VHOST_FILE"; do
    if [[ -e "$ruta" ]]; then
        RUTAS+=("${ruta#/}")
    else
        log WARN "No existe $ruta (se omite)."
    fi
done
log INFO "Comprimiendo archivos: ${RUTAS[*]/#//}"
tar --create --gzip --file "$ARCHIVO.part" \
    --exclude="${APP_DIR#/}/.git" \
    -C "$TMP" basedatos.sql INFO.txt \
    -C / "${RUTAS[@]}"

# Verificación de integridad del archivo generado
tar --list --gzip --file "$ARCHIVO.part" > /dev/null
mv "$ARCHIVO.part" "$ARCHIVO"
( cd "$BACKUP_DIR" && sha256sum "$NOMBRE.tar.gz" > "$NOMBRE.tar.gz.sha256" )
if getent group "$BACKUP_GROUP" > /dev/null && [[ $EUID -eq 0 ]]; then
    chgrp "$BACKUP_GROUP" "$ARCHIVO" "$ARCHIVO.sha256" "$LOG_FILE"
fi
chmod 640 "$ARCHIVO" "$ARCHIVO.sha256"
log INFO "Respaldo local creado: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1)), integridad verificada."

# --- 4. Retención local -------------------------------------------------------
while IFS= read -r viejo; do
    [[ -n "$viejo" ]] || continue
    rm -f "$BACKUP_DIR/$viejo" "$BACKUP_DIR/$viejo.sha256"
    log INFO "Retención local: eliminado $viejo"
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${PREFIX}_*_${TIPO}.tar.gz" -printf '%f\n' | sobrantes "$KEEP_LOCAL")
log INFO "Respaldos locales de tipo '$TIPO' conservados: $(find "$BACKUP_DIR" -maxdepth 1 -name "${PREFIX}_*_${TIPO}.tar.gz" | wc -l) (máximo $KEEP_LOCAL)."

# Desde aquí los errores de la nube no deben borrar el respaldo local.
trap - ERR
set +e

# --- 5. Copia en la nube (Backblaze B2) ---------------------------------------
ESTADO=0
if [[ $SUBIR_NUBE -eq 0 ]]; then
    log INFO "Copia en la nube omitida (--solo-local)."
elif [[ -z "$RCLONE_DEST" ]]; then
    log WARN "Copia en la nube NO configurada (RCLONE_DEST vacío en $CONF_FILE). Ejecutar setup/08_backblaze_rclone.sh"
    ESTADO=2
elif ! command -v rclone > /dev/null; then
    log ERROR "rclone no está instalado: no se pudo subir el respaldo a la nube."
    ESTADO=2
else
    log INFO "Subiendo a la nube: $RCLONE_DEST ..."
    if rclone_cmd copy "$ARCHIVO" "$RCLONE_DEST/" && rclone_cmd copy "$ARCHIVO.sha256" "$RCLONE_DEST/"; then
        # Verificación: el archivo remoto debe existir y tener el mismo tamaño.
        local_bytes=$(stat -c %s "$ARCHIVO")
        remoto_bytes=$(rclone_cmd lsjson "$RCLONE_DEST/$NOMBRE.tar.gz" 2>/dev/null | grep -o '"Size":[0-9]*' | cut -d: -f2)
        if [[ "$remoto_bytes" == "$local_bytes" ]]; then
            log INFO "Transferencia a la nube OK: $NOMBRE.tar.gz ($local_bytes bytes verificados en B2)."
        else
            log ERROR "Transferencia a la nube: tamaño remoto (${remoto_bytes:-ninguno}) distinto del local ($local_bytes)."
            ESTADO=2
        fi
        # Retención en la nube
        if [[ $ESTADO -eq 0 ]]; then
            while IFS= read -r viejo; do
                [[ -n "$viejo" ]] || continue
                if rclone_cmd deletefile --b2-hard-delete "$RCLONE_DEST/$viejo" \
                   && rclone_cmd deletefile --b2-hard-delete "$RCLONE_DEST/$viejo.sha256"; then
                    log INFO "Retención en la nube: eliminado $viejo"
                else
                    log WARN "Retención en la nube: no se pudo eliminar $viejo"
                fi
            done < <(rclone_cmd lsf --files-only --include "${PREFIX}_*_${TIPO}.tar.gz" "$RCLONE_DEST/" | sobrantes "$KEEP_CLOUD")
            log INFO "Respaldos en la nube de tipo '$TIPO': $(rclone_cmd lsf --files-only --include "${PREFIX}_*_${TIPO}.tar.gz" "$RCLONE_DEST/" | wc -l) (máximo $KEEP_CLOUD)."
        fi
    else
        log ERROR "Falló la transferencia a la nube (detalle en $RCLONE_LOG)."
        ESTADO=2
    fi
fi

DURACION=$(( SECONDS - INICIO ))
if [[ $ESTADO -eq 0 ]]; then
    log INFO "===== RESPALDO $NOMBRE FINALIZADO CORRECTAMENTE (${DURACION}s) ====="
else
    log WARN "===== RESPALDO $NOMBRE: LOCAL OK, NUBE CON ERRORES (${DURACION}s) ====="
fi
exit $ESTADO
