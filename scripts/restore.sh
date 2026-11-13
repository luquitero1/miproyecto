#!/usr/bin/env bash
# =============================================================================
#  restore.sh — Recupera la aplicación y la base de datos desde un respaldo
#               local o almacenado en Backblaze B2.
#
#  Uso:
#    sudo restore.sh --listar [--nube]          lista los respaldos disponibles
#    sudo restore.sh [--nube] [ultimo|ARCHIVO] [opciones]
#
#  Opciones:
#    --nube                 toma el respaldo desde Backblaze B2 (lo descarga)
#    --solo-verificar       descarga, verifica y extrae, pero NO restaura nada
#    --solo-bd              restaura sólo la base de datos
#    --solo-archivos        restaura sólo los archivos de la aplicación
#    --bd-destino=NOMBRE    restaura la base en otra base (ej. miproyecto_prueba)
#                           para comprobar el respaldo sin tocar producción
#    --con-config           también restaura /etc/miproyecto (credenciales)
#    --si                   no pide confirmación
#
#  Ejemplos:
#    sudo restore.sh --listar --nube
#    sudo restore.sh --nube ultimo
#    sudo restore.sh --nube ultimo --solo-bd --bd-destino=miproyecto_prueba
#    sudo restore.sh miproyecto_2026-11-14_000000_semanal.tar.gz
#
#  Antes de restaurar sobre producción se genera un respaldo de seguridad
#  local de tipo "prerestauracion".
# =============================================================================
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umask 027

# --- Configuración (misma que backup.sh) --------------------------------------
APP_DIR="/var/www/miproyecto"
CONFIG_DIR="/etc/miproyecto"
DB_NAME="miproyecto"
BACKUP_DIR="/srv/respaldos/local"
LOG_DIR="/srv/respaldos/logs"
RESTORE_DIR="/srv/respaldos/restauracion"
PREFIX="miproyecto"
RCLONE_DEST=""
RCLONE_CONFIG_FILE=""
DB_CLIENT_OPTS=()
APP_GROUP="desarrolladores"

CONF_FILE="${BACKUP_CONF:-/etc/miproyecto/backup.conf}"
if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
fi
BACKUP_BIN="${BACKUP_BIN:-$(command -v backup.sh || echo "$(dirname "$(readlink -f "$0")")/backup.sh")}"

# --- Argumentos ---------------------------------------------------------------
ORIGEN="local"; LISTAR=0; SOLO_VERIFICAR=0; HACER_BD=1; HACER_ARCHIVOS=1
CON_CONFIG=0; CONFIRMAR=1; BD_DESTINO="$DB_NAME"; SELECCION="ultimo"
for arg in "$@"; do
    case "$arg" in
        --nube)            ORIGEN="nube" ;;
        --listar)          LISTAR=1 ;;
        --solo-verificar)  SOLO_VERIFICAR=1 ;;
        --solo-bd)         HACER_ARCHIVOS=0 ;;
        --solo-archivos)   HACER_BD=0 ;;
        --bd-destino=*)    BD_DESTINO="${arg#--bd-destino=}" ;;
        --con-config)      CON_CONFIG=1 ;;
        --si)              CONFIRMAR=0 ;;
        -h|--help)         sed -n '2,32p' "$0"; exit 0 ;;
        -*)                echo "Opción desconocida: $arg (ver --help)" >&2; exit 1 ;;
        *)                 SELECCION="$(basename "$arg")" ;;
    esac
done
[[ "$BD_DESTINO" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Nombre de base inválido: $BD_DESTINO" >&2; exit 1; }
[[ $HACER_BD -eq 1 || $HACER_ARCHIVOS -eq 1 ]] || { echo "--solo-bd y --solo-archivos son excluyentes." >&2; exit 1; }

LOG_FILE="$LOG_DIR/restore.log"
log() {
    local nivel="$1"; shift
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$nivel" "$*" | tee -a "$LOG_FILE"
    logger -t miproyecto-restore -- "[$nivel] $*" 2>/dev/null || true
}
trap 'log ERROR "Fallo en la línea $LINENO (comando: $BASH_COMMAND)"; log ERROR "===== RESTAURACIÓN FALLIDA ====="; exit 1' ERR

rclone_cmd() {
    local args=(--log-file "$LOG_DIR/rclone.log" --log-level INFO)
    [[ -n "$RCLONE_CONFIG_FILE" ]] && args+=(--config "$RCLONE_CONFIG_FILE")
    rclone "${args[@]}" "$@"
}
db() { mariadb "${DB_CLIENT_OPTS[@]}" "$@"; }

listar() {
    if [[ "$ORIGEN" == nube ]]; then
        [[ -n "$RCLONE_DEST" ]] || { echo "RCLONE_DEST no está configurado en $CONF_FILE" >&2; exit 1; }
        rclone_cmd lsf --files-only --format "tsp" --separator ";" --include "${PREFIX}_*.tar.gz" "$RCLONE_DEST/" \
            | sort -t ';' -k3 | awk -F ';' '{ printf "  %s  %12s  %s\n", $1, $2, $3 }'
    else
        find "$BACKUP_DIR" -maxdepth 1 -type f -name "${PREFIX}_*.tar.gz" -printf '%f;%TY-%Tm-%Td %TH:%TM:%.2TS;%s\n' \
            | sort | awk -F ';' '{ printf "  %s  %12s  %s\n", $2, $3, $1 }'
    fi
}

# --- Comprobaciones -------------------------------------------------------------
if [[ $EUID -ne 0 && "${RESTORE_SIN_ROOT:-0}" != 1 ]]; then
    echo "Este script debe ejecutarse como root:  sudo $0" >&2
    exit 1
fi
mkdir -p "$LOG_DIR" "$RESTORE_DIR"
touch "$LOG_FILE"

if [[ $LISTAR -eq 1 ]]; then
    echo "Respaldos disponibles ($ORIGEN) — fecha · tamaño (bytes) · archivo:"
    listar
    exit 0
fi

log INFO "===== INICIO DE LA RESTAURACIÓN (origen: $ORIGEN, selección: $SELECCION) ====="

# --- 1. Elegir el respaldo ----------------------------------------------------------
if [[ "$SELECCION" == ultimo ]]; then
    if [[ "$ORIGEN" == nube ]]; then
        [[ -n "$RCLONE_DEST" ]] || { log ERROR "RCLONE_DEST no está configurado en $CONF_FILE"; exit 1; }
        SELECCION=$(rclone_cmd lsf --files-only --include "${PREFIX}_*.tar.gz" "$RCLONE_DEST/" | sort | tail -n 1)
    else
        SELECCION=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${PREFIX}_*.tar.gz" -printf '%f\n' | sort | tail -n 1)
    fi
    [[ -n "$SELECCION" ]] || { log ERROR "No hay respaldos disponibles en el origen '$ORIGEN'."; exit 1; }
fi
[[ "$SELECCION" == *.tar.gz ]] || SELECCION="$SELECCION.tar.gz"
NOMBRE="${SELECCION%.tar.gz}"
log INFO "Respaldo seleccionado: $SELECCION"

# --- 2. Obtener el archivo ----------------------------------------------------------
if [[ "$ORIGEN" == nube ]]; then
    DESCARGAS="$RESTORE_DIR/descargas"
    mkdir -p "$DESCARGAS"
    log INFO "Descargando desde $RCLONE_DEST ..."
    rclone_cmd copy "$RCLONE_DEST/$SELECCION" "$DESCARGAS/"
    rclone_cmd copy "$RCLONE_DEST/$SELECCION.sha256" "$DESCARGAS/" || log WARN "No se encontró el archivo .sha256 en la nube."
    [[ -f "$DESCARGAS/$SELECCION" ]] || { log ERROR "No se pudo descargar $SELECCION"; exit 1; }
    ARCHIVO="$DESCARGAS/$SELECCION"
    log INFO "Descarga completa: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))."
else
    ARCHIVO="$BACKUP_DIR/$SELECCION"
    [[ -f "$ARCHIVO" ]] || { log ERROR "No existe $ARCHIVO"; exit 1; }
fi

# --- 3. Verificar integridad ------------------------------------------------------
if [[ -f "$ARCHIVO.sha256" ]]; then
    ( cd "$(dirname "$ARCHIVO")" && sha256sum --check --quiet "$SELECCION.sha256" ) \
        || { log ERROR "La suma SHA-256 NO coincide: el respaldo está dañado."; exit 1; }
    log INFO "Integridad verificada (SHA-256 correcto)."
else
    log WARN "Sin archivo .sha256: se verifica sólo que el .tar.gz se pueda leer."
fi
tar --list --gzip --file "$ARCHIVO" > /dev/null

# --- 4. Extraer -------------------------------------------------------------------
EXTR="$RESTORE_DIR/$NOMBRE"
rm -rf "$EXTR"
mkdir -p "$EXTR"
tar --extract --gzip --same-owner --file "$ARCHIVO" -C "$EXTR"
log INFO "Respaldo extraído en $EXTR"
echo "-------------------------------------------------------------"
cat "$EXTR/INFO.txt" 2>/dev/null || true
echo "Tablas en el volcado:             $(grep -c '^CREATE TABLE' "$EXTR/basedatos.sql" || true)"
echo "Archivos de la aplicación:        $(find "$EXTR/${APP_DIR#/}" -type f 2>/dev/null | wc -l)"
echo "-------------------------------------------------------------"

if [[ $SOLO_VERIFICAR -eq 1 ]]; then
    log INFO "Modo --solo-verificar: el respaldo es válido. No se restauró nada."
    log INFO "===== VERIFICACIÓN FINALIZADA ====="
    exit 0
fi

# --- 5. Confirmación --------------------------------------------------------------
echo "Se va a restaurar:"
[[ $HACER_BD -eq 1 ]]       && echo "  • Base de datos  -> '$BD_DESTINO' (se reemplazan sus tablas)"
[[ $HACER_ARCHIVOS -eq 1 ]] && echo "  • Archivos       -> $APP_DIR"
[[ $HACER_ARCHIVOS -eq 1 && $CON_CONFIG -eq 1 ]] && echo "  • Configuración  -> $CONFIG_DIR"
if [[ $CONFIRMAR -eq 1 ]]; then
    read -r -p "¿Continuar? (escribí SI para confirmar): " resp
    [[ "$resp" == "SI" || "$resp" == "si" ]] || { log INFO "Restauración cancelada por el usuario."; exit 0; }
fi

# --- 6. Respaldo de seguridad previo (si se toca producción) ----------------------
if [[ $HACER_ARCHIVOS -eq 1 || "$BD_DESTINO" == "$DB_NAME" ]] && [[ "${SIN_RESPALDO_PREVIO:-0}" != 1 ]]; then
    log INFO "Generando respaldo de seguridad previo (tipo prerestauracion)..."
    if "$BACKUP_BIN" --tipo=prerestauracion --solo-local > /dev/null; then
        log INFO "Respaldo de seguridad previo generado."
    else
        log WARN "No se pudo generar el respaldo previo (se continúa)."
    fi
fi

# --- 7. Restaurar base de datos ---------------------------------------------------
if [[ $HACER_BD -eq 1 ]]; then
    log INFO "Restaurando base de datos en '$BD_DESTINO'..."
    db -e "CREATE DATABASE IF NOT EXISTS \`$BD_DESTINO\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    db "$BD_DESTINO" < "$EXTR/basedatos.sql"
    TOTAL=$(db -N -e "SELECT COUNT(*) FROM \`$BD_DESTINO\`.equipos" 2>/dev/null || echo '?')
    log INFO "Base de datos restaurada: $TOTAL registro(s) en la tabla equipos."
fi

# --- 8. Restaurar archivos --------------------------------------------------------
if [[ $HACER_ARCHIVOS -eq 1 ]]; then
    ORIG_APP="$EXTR/${APP_DIR#/}"
    [[ -d "$ORIG_APP" ]] || { log ERROR "El respaldo no contiene $APP_DIR"; exit 1; }
    mkdir -p "$APP_DIR"
    rsync -a --delete --exclude='.git/' "$ORIG_APP/" "$APP_DIR/"
    log INFO "Archivos de la aplicación restaurados en $APP_DIR."
    if [[ $CON_CONFIG -eq 1 && -d "$EXTR/${CONFIG_DIR#/}" ]]; then
        rsync -a "$EXTR/${CONFIG_DIR#/}/" "$CONFIG_DIR/"
        log INFO "Configuración restaurada en $CONFIG_DIR."
    fi
    if [[ -d "$APP_DIR/.git" ]]; then
        log INFO "Nota: si el código del respaldo es anterior al de GitHub, 'sudo deploy.sh' lo vuelve a sincronizar."
    fi
fi

log INFO "===== RESTAURACIÓN FINALIZADA CORRECTAMENTE ====="
