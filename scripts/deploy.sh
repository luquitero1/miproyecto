#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — Actualiza la aplicación de http://miproyecto.com desde GitHub
#
#  Uso:   sudo deploy.sh            (instalado en /usr/local/bin por el setup)
#
#  Pasos:
#    1. Descarga los cambios de la rama main del repositorio de GitHub.
#    2. Deja el código del servidor idéntico a origin/main.
#    3. Verifica la sintaxis de los archivos PHP; si hay errores, vuelve atrás.
#    4. Ajusta propietarios y permisos.
#    5. Recarga Apache y comprueba que el sitio responda.
#  Todo queda registrado en /var/log/miproyecto/deploy.log
# =============================================================================
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# --- Configuración (se puede sobrescribir con variables de entorno) ----------
APP_DIR="${APP_DIR:-/var/www/miproyecto}"
BRANCH="${BRANCH:-main}"
REMOTE="${REMOTE:-origin}"
APP_GROUP="${APP_GROUP:-desarrolladores}"
SITE_URL="${SITE_URL:-http://127.0.0.1/}"
SITE_HOST="${SITE_HOST:-miproyecto.com}"
LOG_FILE="${LOG_FILE:-/var/log/miproyecto/deploy.log}"
LOCK_FILE="${LOCK_FILE:-/run/lock/miproyecto-deploy.lock}"

# --- Funciones auxiliares -----------------------------------------------------
log() {
    local nivel="$1"; shift
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$nivel" "$*" | tee -a "$LOG_FILE"
}
fallo() {
    log ERROR "$*"
    log ERROR "===== DESPLIEGUE FALLIDO ====="
    exit 1
}
trap 'fallo "Error inesperado en la línea $LINENO (comando: $BASH_COMMAND)"' ERR

# git con medidas de seguridad: sólo confía en este directorio y no ejecuta hooks.
g() { git -c safe.directory="$APP_DIR" -c core.hooksPath=/dev/null -C "$APP_DIR" "$@"; }

# --- Comprobaciones previas ---------------------------------------------------
if [[ $EUID -ne 0 && "${DEPLOY_SIN_ROOT:-0}" != 1 ]]; then
    echo "Este script debe ejecutarse como root:  sudo $0" >&2
    exit 1
fi
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Ya hay un despliegue en curso." >&2; exit 1; }

log INFO "===== INICIO DEL DESPLIEGUE (usuario: ${SUDO_USER:-$USER}) ====="
[[ -d "$APP_DIR/.git" ]] || fallo "$APP_DIR no es un repositorio Git. Ejecutá primero setup/04_clonar_repositorio.sh"

ANTES=$(g rev-parse HEAD)
log INFO "Versión actual: $(g log -1 --format='%h - %s (%an, %ad)' --date=short)"

if [[ -n "$(g status --porcelain --untracked-files=no)" ]]; then
    log WARN "Había cambios locales sin subir a GitHub; se descartan (el servidor sólo toma código de GitHub):"
    g status --short --untracked-files=no | tee -a "$LOG_FILE"
fi

# --- 1. Descargar cambios -----------------------------------------------------
log INFO "Descargando cambios de $REMOTE/$BRANCH ($(g remote get-url "$REMOTE"))..."
g fetch --prune "$REMOTE" "$BRANCH" 2>&1 | tee -a "$LOG_FILE" || fallo "No se pudo contactar al repositorio remoto."

DESPUES=$(g rev-parse "$REMOTE/$BRANCH")
if [[ "$ANTES" == "$DESPUES" ]]; then
    log INFO "No hay cambios nuevos: el servidor ya tiene la última versión."
else
    log INFO "Cambios a aplicar:"
    g log --format='    %h %s (%an)' "$ANTES..$DESPUES" | tee -a "$LOG_FILE"
fi

# --- 2. Actualizar el código --------------------------------------------------
g checkout -q -B "$BRANCH" "$REMOTE/$BRANCH"
g reset -q --hard "$REMOTE/$BRANCH"

# --- 3. Verificar sintaxis PHP (si falla, se vuelve a la versión anterior) ----
ERRORES_PHP=0
while IFS= read -r -d '' archivo; do
    if ! salida=$(php -l "$archivo" 2>&1); then
        log ERROR "$salida"
        ERRORES_PHP=1
    fi
done < <(find "$APP_DIR" -path "$APP_DIR/.git" -prune -o -name '*.php' -type f -print0)

if [[ $ERRORES_PHP -ne 0 ]]; then
    log ERROR "Se encontraron errores de sintaxis PHP. Volviendo a la versión anterior ($(g rev-parse --short "$ANTES"))."
    g reset -q --hard "$ANTES"
    fallo "Despliegue cancelado: corregí los errores, subí los cambios a GitHub y volvé a ejecutar deploy.sh."
fi
log INFO "Sintaxis PHP verificada correctamente."

# --- 4. Propietarios y permisos ------------------------------------------------
#  * Código: root:desarrolladores, grupo con escritura, Apache (otros) sólo lectura.
#  * .git:   sólo root puede modificarlo (evita que se inyecten hooks o configuración).
if getent group "$APP_GROUP" >/dev/null && [[ $EUID -eq 0 ]]; then
    find "$APP_DIR" -path "$APP_DIR/.git" -prune -o -exec chown -h root:"$APP_GROUP" {} +
    find "$APP_DIR" -path "$APP_DIR/.git" -prune -o -type d -exec chmod 2775 {} +
    find "$APP_DIR" -path "$APP_DIR/.git" -prune -o -type f -exec chmod g+rw,o+r,o-w {} +
    chown -hR root:root "$APP_DIR/.git"
    chmod -R go-w "$APP_DIR/.git"
    log INFO "Permisos ajustados (root:$APP_GROUP, 2775/664; .git sólo root)."
else
    log WARN "No se ajustaron permisos (grupo $APP_GROUP inexistente o sin privilegios de root)."
fi

# --- 5. Recargar Apache y comprobar el sitio ------------------------------------
if [[ $EUID -eq 0 ]] && command -v systemctl >/dev/null && systemctl is-active --quiet apache2; then
    systemctl reload apache2 && log INFO "Apache recargado."
fi

if command -v curl >/dev/null; then
    codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "Host: $SITE_HOST" "$SITE_URL" || true)
    if [[ "$codigo" == 200 ]]; then
        log INFO "Comprobación del sitio: http://$SITE_HOST responde HTTP $codigo."
    else
        log WARN "Comprobación del sitio: http://$SITE_HOST respondió HTTP ${codigo:-sin respuesta}. Revisar /var/log/apache2/miproyecto_error.log"
    fi
fi

log INFO "Versión desplegada: $(g log -1 --format='%h - %s (%an, %ad)' --date=short)"
log INFO "===== DESPLIEGUE FINALIZADO CORRECTAMENTE ====="
