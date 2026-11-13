#!/usr/bin/env bash
# =============================================================================
#  Instalación completa del servidor (partes 1 a 7) en un solo paso.
#
#  Uso:  sudo bash setup/instalar_todo.sh [nombre-del-equipo]
#        (por defecto: centro-computos)
#
#  1. Desactiva el servicio Docker (el práctico no permite contenedores).
#  2. Ejecuta en orden: 01_sistema, 02_usuarios_grupos, 03_servicios,
#     04_clonar_repositorio (desde el remoto "origin" de este repositorio),
#     05_base_datos, 06_apache_vhost, 07_respaldos_cron y la verificación de permisos.
#  Todo queda registrado en /var/log/miproyecto/instalacion.log
#
#  La parte 8 (Backblaze B2) se ejecuta aparte porque pide las credenciales:
#        sudo bash setup/08_backblaze_rclone.sh
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

NOMBRE_EQUIPO="${1:-centro-computos}"
DIR="$REPO_DIR/setup"
REPO_URL="${REPO_URL:-$(git -c safe.directory="$REPO_DIR" -C "$REPO_DIR" remote get-url origin 2> /dev/null || true)}"
[[ "$REPO_URL" == https://github.com/* ]] || morir "No se encontró la URL de GitHub (remoto origin). Ejecutar: REPO_URL=https://github.com/USUARIO/miproyecto.git sudo -E bash $0"

# La contraseña de los usuarios se pide al principio para no interrumpir después.
if [[ -z "${CLAVE_INICIAL:-}" ]]; then
    read -r -s -p "Contraseña inicial para los usuarios ana, bruno, carla, diego, elena y fabian: " CLAVE_INICIAL; echo
    read -r -s -p "Repetir contraseña: " CLAVE2; echo
    [[ "$CLAVE_INICIAL" == "$CLAVE2" ]] || morir "Las contraseñas no coinciden"
    [[ ${#CLAVE_INICIAL} -ge 8 ]] || morir "La contraseña debe tener al menos 8 caracteres"
fi
export CLAVE_INICIAL

mkdir -p "$LOG_APP_DIR"
LOG="$LOG_APP_DIR/instalacion.log"
exec > >(tee -a "$LOG") 2>&1
echo "===== Instalación iniciada: $(date '+%F %T') — repositorio: $REPO_URL ====="

titulo "0. Desactivar Docker"
if systemctl list-unit-files docker.service &> /dev/null && systemctl list-unit-files docker.service | grep -q docker; then
    if command -v docker > /dev/null && [[ -n "$(docker ps -q 2> /dev/null)" ]]; then
        ejecutar docker stop $(docker ps -q)
    fi
    ejecutar systemctl disable --now docker.socket docker.service
    ok "Docker detenido y deshabilitado (reactivar luego con: sudo systemctl enable --now docker)"
else
    ok "Docker no está instalado"
fi

paso_setup() {
    local script="$1"; shift
    titulo ">>> setup/$script $*"
    bash "$DIR/$script" "$@" || morir "Falló setup/$script — revisar el mensaje anterior y volver a ejecutar este instalador (los pasos ya hechos no se rompen)."
}

paso_setup 01_sistema.sh "$NOMBRE_EQUIPO"
paso_setup 02_usuarios_grupos.sh
paso_setup 03_servicios.sh
paso_setup 04_clonar_repositorio.sh "$REPO_URL"
paso_setup 05_base_datos.sh
paso_setup 06_apache_vhost.sh
paso_setup 07_respaldos_cron.sh
paso_setup 02_verificar_permisos.sh

titulo "Instalación de las partes 1 a 7 finalizada"
ok "Aplicación: http://$DOMINIO   ·   Estado: http://$DOMINIO/estado.php"
ok "Registro de la instalación: $LOG"
aviso "Falta la parte 8:  sudo bash setup/08_backblaze_rclone.sh  (con keyID, applicationKey y bucket de Backblaze)"
aviso "Se recomienda reiniciar (sudo reboot) para comprobar que todos los servicios arrancan solos."
