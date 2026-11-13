#!/usr/bin/env bash
# =============================================================================
#  PARTE 1 — Implementación del centro de cómputos
#
#  Uso:  sudo bash setup/01_sistema.sh [nombre-del-equipo]
#        (por defecto: centro-computos)
#
#  - Configura el nombre del equipo
#  - Verifica red y conectividad
#  - Actualiza el sistema operativo
#  - Instala herramientas de administración
#  - Instala y configura OpenSSH Server
#  - Crea la estructura de directorios para proyectos y respaldos
#  - Muestra el estado y los recursos del sistema
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

NOMBRE_EQUIPO="${1:-centro-computos}"
[[ "$NOMBRE_EQUIPO" =~ ^[a-zA-Z0-9-]{1,63}$ ]] || morir "Nombre de equipo inválido: $NOMBRE_EQUIPO"

# --- Nombre del equipo --------------------------------------------------------
titulo "1. Nombre del equipo"
ANTERIOR=$(hostname)
if [[ "$ANTERIOR" != "$NOMBRE_EQUIPO" ]]; then
    ejecutar hostnamectl set-hostname "$NOMBRE_EQUIPO"
    # Debian resuelve el propio nombre mediante la línea 127.0.1.1 de /etc/hosts
    if grep -qE '^127\.0\.1\.1\s' /etc/hosts; then
        sed -i -E "s/^127\.0\.1\.1\s.*/127.0.1.1\t$NOMBRE_EQUIPO/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$NOMBRE_EQUIPO" >> /etc/hosts
    fi
    ok "Nombre cambiado: $ANTERIOR -> $NOMBRE_EQUIPO"
else
    ok "El equipo ya se llama $NOMBRE_EQUIPO"
fi
hostnamectl | sed -n '1,3p;/Operating/p'

# --- Red ----------------------------------------------------------------------
titulo "2. Configuración de red y conectividad"
ejecutar ip -brief address show
ejecutar ip route show default
if ping -c 3 -W 2 8.8.8.8 > /dev/null; then ok "Hay conectividad a Internet"; else morir "Sin conectividad: revisar la red antes de continuar"; fi
if getent hosts deb.debian.org > /dev/null; then ok "La resolución DNS funciona"; else morir "Falla el DNS"; fi

# --- Actualización ------------------------------------------------------------
titulo "3. Actualización del sistema operativo"
export DEBIAN_FRONTEND=noninteractive
ejecutar apt-get update
ejecutar "${APT[@]}" full-upgrade
ejecutar "${APT[@]}" autoremove

# --- Herramientas -------------------------------------------------------------
titulo "4. Herramientas de administración"
HERRAMIENTAS=(sudo curl wget vim nano htop tree net-tools dnsutils iputils-ping traceroute
              rsync zip unzip acl lsof sysstat bash-completion ca-certificates cron git logrotate)
ejecutar "${APT[@]}" install "${HERRAMIENTAS[@]}"
ejecutar systemctl enable --now cron
ok "Herramientas instaladas"

# --- SSH ----------------------------------------------------------------------
titulo "5. OpenSSH Server"
ejecutar "${APT[@]}" install openssh-server
cat > /etc/ssh/sshd_config.d/10-centro-computos.conf <<'EOF'
# Configuración del centro de cómputos (Parte 1 del práctico)
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
# Sólo pueden ingresar por SSH los miembros de estos grupos
AllowGroups sudo administradores desarrolladores respaldos
Banner /etc/issue.net
EOF
cat > /etc/issue.net <<'EOF'
*****************************************************************
*  Centro de Cómputos — acceso exclusivo para personal autorizado *
*  Todas las conexiones quedan registradas.                      *
*****************************************************************
EOF
ejecutar sshd -t
ejecutar systemctl enable ssh
ejecutar systemctl restart ssh
systemctl --no-pager --lines=0 status ssh | head -5
ok "SSH escuchando en el puerto 22 (probar: ssh usuario@$(hostname -I | awk '{print $1}'))"

# --- Directorios --------------------------------------------------------------
titulo "6. Estructura de directorios"
# Los grupos y permisos definitivos se asignan en la Parte 2 (02_usuarios_grupos.sh)
for d in /srv/administracion /srv/proyectos /srv/compartido \
         "$RESPALDOS_DIR" "$RESPALDOS_DIR/local" "$RESPALDOS_DIR/logs" "$RESPALDOS_DIR/restauracion" \
         "$LOG_APP_DIR"; do
    mkdir -p "$d"
    ok "$d"
done
ejecutar tree -d -L 2 /srv

# --- Estado ------------------------------------------------------------------
titulo "7. Estado y recursos del sistema"
bash "$(dirname "$0")/info_sistema.sh"

titulo "Parte 1 finalizada"
if [[ "$ANTERIOR" != "$NOMBRE_EQUIPO" ]]; then
    aviso "El nuevo nombre se ve en el prompt al abrir una nueva terminal."
fi
