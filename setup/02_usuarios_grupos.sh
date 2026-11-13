#!/usr/bin/env bash
# =============================================================================
#  PARTE 2 — Usuarios, grupos y permisos
#
#  Uso:  sudo bash setup/02_usuarios_grupos.sh [--forzar-cambio]
#
#  La contraseña inicial se pide por teclado (o variable CLAVE_INICIAL).
#  --forzar-cambio  obliga a cada usuario a cambiarla en su primer ingreso.
#
#  Grupos y usuarios:
#    administradores : ana, bruno     (configuración del servidor, con sudo)
#    desarrolladores : carla, diego   (archivos de la aplicación, deploy.sh)
#    respaldos       : elena, fabian  (copias de seguridad, backup/restore.sh)
#
#  Directorios:
#    /srv/administracion   privado de administradores        2770 root:administradores
#    /srv/proyectos        privado de desarrolladores        2770 root:desarrolladores
#    /srv/respaldos        privado de respaldos              2770 root:respaldos
#    /srv/compartido       compartido por los tres grupos    3770 + ACL (sticky)
#    /home/<usuario>       privado de cada usuario           0700
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

FORZAR_CAMBIO=0
[[ "${1:-}" == "--forzar-cambio" ]] && FORZAR_CAMBIO=1

# usuario:grupo:nombre completo
USUARIOS=(
    "ana:$GRUPO_ADMIN:Ana Gómez - Administradora"
    "bruno:$GRUPO_ADMIN:Bruno Díaz - Administrador"
    "carla:$GRUPO_DEV:Carla Méndez - Desarrolladora"
    "diego:$GRUPO_DEV:Diego Rivas - Desarrollador"
    "elena:$GRUPO_BACKUP:Elena Suárez - Respaldos"
    "fabian:$GRUPO_BACKUP:Fabián López - Respaldos"
)

# --- Contraseña inicial ---------------------------------------------------------
if [[ -z "${CLAVE_INICIAL:-}" ]]; then
    read -r -s -p "Contraseña inicial para los usuarios nuevos: " CLAVE_INICIAL; echo
    read -r -s -p "Repetir contraseña: " CLAVE2; echo
    [[ "$CLAVE_INICIAL" == "$CLAVE2" ]] || morir "Las contraseñas no coinciden"
fi
[[ ${#CLAVE_INICIAL} -ge 8 ]] || morir "La contraseña debe tener al menos 8 caracteres"

# --- Grupos -------------------------------------------------------------------
titulo "1. Grupos"
for g in "$GRUPO_ADMIN" "$GRUPO_DEV" "$GRUPO_BACKUP"; do
    if getent group "$g" > /dev/null; then ok "El grupo $g ya existe"; else ejecutar groupadd "$g"; ok "Grupo $g creado"; fi
done

# --- Usuarios -----------------------------------------------------------------
titulo "2. Usuarios"
for entrada in "${USUARIOS[@]}"; do
    IFS=: read -r usuario grupo nombre <<< "$entrada"
    if id "$usuario" &> /dev/null; then
        ejecutar usermod -c "$nombre" -s /bin/bash -aG "$grupo" "$usuario"
        ok "$usuario ya existía: datos actualizados"
    else
        # -m crea /home/usuario · -G agrega el grupo de su rol (además de su grupo personal)
        ejecutar useradd -m -s /bin/bash -c "$nombre" -G "$grupo" "$usuario"
        printf '%s:%s\n' "$usuario" "$CLAVE_INICIAL" | chpasswd
        ok "$usuario creado y contraseña asignada"
    fi
    # Los administradores además pertenecen al grupo sudo
    if [[ "$grupo" == "$GRUPO_ADMIN" ]]; then usermod -aG sudo "$usuario"; fi
    # Política de contraseñas: vence a los 90 días, aviso 7 días antes
    chage -M 90 -m 0 -W 7 "$usuario"
    [[ $FORZAR_CAMBIO -eq 1 ]] && chage -d 0 "$usuario"
    # Directorio personal privado
    chmod 700 "/home/$usuario"
done

# El usuario que ejecuta el práctico también queda como administrador
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    usermod -aG "$GRUPO_ADMIN" "$SUDO_USER"
    ok "$SUDO_USER agregado al grupo $GRUPO_ADMIN"
fi

# --- Directorios y permisos ---------------------------------------------------
titulo "3. Directorios privados de cada grupo"
crear_dir() {  # crear_dir <ruta> <grupo> <modo>
    mkdir -p "$1"
    chown root:"$2" "$1"
    chmod "$3" "$1"
    stat -c '  %A  %U:%G  %n' "$1"
}
crear_dir /srv/administracion "$GRUPO_ADMIN"  2770
crear_dir /srv/proyectos      "$GRUPO_DEV"    2770
crear_dir "$RESPALDOS_DIR"              "$GRUPO_BACKUP" 2770
crear_dir "$RESPALDOS_DIR/local"        "$GRUPO_BACKUP" 2770
crear_dir "$RESPALDOS_DIR/logs"         "$GRUPO_BACKUP" 2770
crear_dir "$RESPALDOS_DIR/restauracion" "$GRUPO_BACKUP" 2770
# Logs de despliegue: los escribe root, los leen desarrolladores y administradores
crear_dir "$LOG_APP_DIR" "$GRUPO_DEV" 2750
setfacl -m g:"$GRUPO_ADMIN":rx "$LOG_APP_DIR"

titulo "4. Directorio compartido por los tres grupos (ACL)"
crear_dir /srv/compartido "$GRUPO_ADMIN" 3770     # setgid + sticky: cada uno borra sólo lo suyo
for g in "$GRUPO_ADMIN" "$GRUPO_DEV" "$GRUPO_BACKUP"; do
    setfacl    -m g:"$g":rwx /srv/compartido      # permiso actual
    setfacl -d -m g:"$g":rwx /srv/compartido      # permiso heredado por archivos nuevos
done
getfacl -p /srv/compartido 2>/dev/null | sed 's/^/    /'

# --- sudo restringido por grupo ------------------------------------------------
titulo "5. Permisos de sudo por grupo"
SUDOERS_TMP=$(mktemp)
cat > "$SUDOERS_TMP" <<EOF
# Centro de cómputos — privilegios por grupo
# Administradores: acceso total mediante el grupo "sudo" (ver /etc/sudoers)
# Desarrolladores: sólo pueden desplegar la aplicación
%$GRUPO_DEV ALL=(root) /usr/local/bin/deploy.sh
# Respaldos: sólo pueden generar y restaurar copias de seguridad
%$GRUPO_BACKUP ALL=(root) /usr/local/bin/backup.sh, /usr/local/bin/restore.sh
EOF
visudo -cf "$SUDOERS_TMP" > /dev/null || morir "Error de sintaxis en sudoers"
install -o root -g root -m 440 "$SUDOERS_TMP" /etc/sudoers.d/centro-computos
rm -f "$SUDOERS_TMP"
ok "/etc/sudoers.d/centro-computos instalado"
sed 's/^/    /' /etc/sudoers.d/centro-computos | grep -v '^    #'

# --- Resumen ------------------------------------------------------------------
titulo "Resumen"
for g in "$GRUPO_ADMIN" "$GRUPO_DEV" "$GRUPO_BACKUP"; do
    printf '  %-16s %s\n' "$g" "$(getent group "$g" | cut -d: -f4)"
done
echo
for entrada in "${USUARIOS[@]}"; do
    usuario=${entrada%%:*}
    printf '  %-8s %s\n' "$usuario" "$(id "$usuario")"
done
echo
ok "Verificá los accesos con:  sudo bash setup/02_verificar_permisos.sh"
