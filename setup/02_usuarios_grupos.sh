#!/usr/bin/env bash
set -euo pipefail

read -r -s -p "Contraseña inicial para los usuarios: " CLAVE
echo

for grupo in administradores desarrolladores respaldos; do
    getent group "$grupo" > /dev/null || groupadd "$grupo"
done

crear_usuario() {
    if ! id "$1" &> /dev/null; then
        useradd -m -s /bin/bash -c "$3" -G "$2" "$1"
        echo "$1:$CLAVE" | chpasswd
    fi
    chmod 700 "/home/$1"
}
crear_usuario ana administradores "Ana Gómez"
crear_usuario bruno administradores "Bruno Díaz"
crear_usuario carla desarrolladores "Carla Méndez"
crear_usuario diego desarrolladores "Diego Rivas"
crear_usuario elena respaldos "Elena Suárez"
crear_usuario fabian respaldos "Fabián López"
usermod -aG sudo ana
usermod -aG sudo bruno
[[ -n "${SUDO_USER:-}" ]] && usermod -aG administradores "$SUDO_USER"

directorio() {
    mkdir -p "$1"
    chown root:"$2" "$1"
    chmod "$3" "$1"
}
directorio /srv/administracion administradores 2770
directorio /srv/proyectos desarrolladores 2770
directorio /srv/respaldos respaldos 2770
directorio /srv/respaldos/local respaldos 2770
directorio /srv/respaldos/logs respaldos 2770
directorio /srv/respaldos/restauracion respaldos 2770
directorio /var/log/miproyecto desarrolladores 2750
setfacl -m g:administradores:rx /var/log/miproyecto

directorio /srv/compartido administradores 3770
for grupo in administradores desarrolladores respaldos; do
    setfacl -m g:"$grupo":rwx /srv/compartido
    setfacl -d -m g:"$grupo":rwx /srv/compartido
done

cat > /etc/sudoers.d/centro-computos <<'EOF'
%desarrolladores ALL=(root) /usr/local/bin/deploy.sh
%respaldos ALL=(root) /usr/local/bin/backup.sh, /usr/local/bin/restore.sh
EOF
chmod 440 /etc/sudoers.d/centro-computos
visudo -c

getent group administradores desarrolladores respaldos
