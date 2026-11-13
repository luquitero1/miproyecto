#!/usr/bin/env bash
# Funciones y variables comunes para los scripts de instalación (setup/*.sh).
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# --- Parámetros generales del proyecto ----------------------------------------
DOMINIO="${DOMINIO:-miproyecto.com}"
APP_DIR="${APP_DIR:-/var/www/miproyecto}"
CONFIG_DIR="${CONFIG_DIR:-/etc/miproyecto}"
DB_NAME="${DB_NAME:-miproyecto}"
DB_USER="${DB_USER:-miproyecto_app}"
RESPALDOS_DIR="${RESPALDOS_DIR:-/srv/respaldos}"
LOG_APP_DIR="${LOG_APP_DIR:-/var/log/miproyecto}"
GRUPO_ADMIN="administradores"
GRUPO_DEV="desarrolladores"
GRUPO_BACKUP="respaldos"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Salida con formato -----------------------------------------------------------
if [[ -t 1 ]]; then
    C_AZUL=$'\e[1;34m'; C_VERDE=$'\e[1;32m'; C_AMARILLO=$'\e[1;33m'; C_ROJO=$'\e[1;31m'; C_NEGRITA=$'\e[1m'; C_FIN=$'\e[0m'
else
    C_AZUL=""; C_VERDE=""; C_AMARILLO=""; C_ROJO=""; C_NEGRITA=""; C_FIN=""
fi
titulo() { printf '\n%s══════ %s ══════%s\n' "$C_AZUL" "$*" "$C_FIN"; }
paso()   { printf '%s▶ %s%s\n' "$C_NEGRITA" "$*" "$C_FIN"; }
ok()     { printf '  %s✔%s %s\n' "$C_VERDE" "$C_FIN" "$*"; }
aviso()  { printf '  %s⚠ %s%s\n' "$C_AMARILLO" "$*" "$C_FIN"; }
error()  { printf '  %s✘ %s%s\n' "$C_ROJO" "$*" "$C_FIN" >&2; }
morir()  { error "$*"; exit 1; }

trap 'error "Falló el comando en la línea $LINENO: $BASH_COMMAND"' ERR

requiere_root() {
    [[ $EUID -eq 0 ]] || morir "Ejecutá este script con sudo:  sudo $0 $*"
}

# Ejecuta un comando mostrándolo antes (útil para la demostración en clase).
ejecutar() {
    printf '  %s$ %s%s\n' "$C_AMARILLO" "$*" "$C_FIN"
    "$@"
}

# Genera una contraseña aleatoria alfanumérica de 24 caracteres.
clave_aleatoria() {
    local c
    c=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 512 /dev/urandom))
    printf '%s' "${c:0:24}"
}

# Ajusta propietarios y permisos del código de la aplicación.
permisos_aplicacion() {
    local dir="${1:-$APP_DIR}"
    find "$dir" -path "$dir/.git" -prune -o -exec chown -h root:"$GRUPO_DEV" {} +
    find "$dir" -path "$dir/.git" -prune -o -type d -exec chmod 2775 {} +
    find "$dir" -path "$dir/.git" -prune -o -type f -exec chmod g+rw,o+r,o-w {} +
    if [[ -d "$dir/.git" ]]; then
        chown -hR root:root "$dir/.git"
        chmod -R go-w "$dir/.git"
    fi
}

# Instala los scripts operativos en /usr/local/bin (copias propiedad de root).
instalar_scripts() {
    local origen="${1:-$APP_DIR/scripts}"
    for s in deploy.sh backup.sh restore.sh; do
        install -o root -g root -m 755 "$origen/$s" "/usr/local/bin/$s"
        ok "/usr/local/bin/$s instalado"
    done
}
