#!/usr/bin/env bash
# =============================================================================
#  PARTE 5/6 — Clonar el repositorio de GitHub en /var/www/miproyecto
#
#  Uso:  sudo bash setup/04_clonar_repositorio.sh https://github.com/USUARIO/miproyecto.git
#
#  - Clona la rama main en /var/www/miproyecto
#  - Asigna permisos: código del grupo desarrolladores, Apache sólo lectura
#  - Instala deploy.sh, backup.sh y restore.sh en /usr/local/bin
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

URL="${1:-}"
[[ -n "$URL" ]] || morir "Indicá la URL del repositorio:  sudo bash $0 https://github.com/USUARIO/miproyecto.git"
getent group "$GRUPO_DEV" > /dev/null || morir "Falta el grupo $GRUPO_DEV (ejecutar antes 02_usuarios_grupos.sh)"

titulo "1. Clonar el repositorio"
if [[ -d "$APP_DIR/.git" ]]; then
    aviso "$APP_DIR ya es un repositorio ($(git -c safe.directory="$APP_DIR" -C "$APP_DIR" remote get-url origin)); no se vuelve a clonar."
    aviso "Para actualizarlo usá:  sudo deploy.sh"
elif [[ -e "$APP_DIR" && -n "$(ls -A "$APP_DIR" 2> /dev/null)" ]]; then
    morir "$APP_DIR existe y no está vacío. Movelo o borralo antes de clonar."
else
    ejecutar git clone --branch main "$URL" "$APP_DIR"
fi
# Permite que root y los desarrolladores usen git en este directorio
git config --system --get-all safe.directory 2> /dev/null | grep -qx "$APP_DIR" \
    || git config --system --add safe.directory "$APP_DIR"
git -C "$APP_DIR" log -1 --format='  Último commit: %h %s (%an, %ad)' --date=short

titulo "2. Permisos del directorio de la aplicación"
permisos_aplicacion "$APP_DIR"
chmod 755 /var/www
ok "Código: root:$GRUPO_DEV, directorios 2775, archivos 664 (Apache lee como 'otros')"
ok ".git: sólo root (evita que se modifiquen hooks o la configuración del repositorio)"
ls -la "$APP_DIR" | sed 's/^/    /'

titulo "3. Scripts operativos"
instalar_scripts "$APP_DIR/scripts"
mkdir -p "$LOG_APP_DIR"
ok "Para desplegar cambios:  sudo deploy.sh"
