#!/usr/bin/env bash
# =============================================================================
#  PARTE 8 — Respaldos en la nube con Backblaze B2 y Rclone
#
#  Uso:  sudo bash setup/08_backblaze_rclone.sh
#
#  Requisitos previos (en https://www.backblaze.com, ver docs/GUIA.md):
#    1. Cuenta de Backblaze B2.
#    2. Bucket PRIVADO (ej.: miproyecto-respaldos-<tu-nombre>).
#    3. Application Key con acceso de lectura y escritura a ese bucket
#       (anotar keyID y applicationKey: la clave se muestra una sola vez).
#
#  El script:
#    - instala rclone
#    - guarda las credenciales en /root/.config/rclone/rclone.conf (permisos 600,
#      fuera del repositorio: NUNCA se suben a GitHub)
#    - verifica el acceso al bucket (subida, listado y borrado de prueba)
#    - configura RCLONE_DEST en /etc/miproyecto/backup.conf
#    - ejecuta un respaldo completo y lo muestra en la nube
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

REMOTO="b2"
CONF="$CONFIG_DIR/backup.conf"
RCLONE_CONF="/root/.config/rclone/rclone.conf"
export RCLONE_CONFIG="$RCLONE_CONF"   # rclone usa siempre la configuración de root
[[ -f "$CONF" ]] || morir "Falta $CONF (ejecutar antes 07_respaldos_cron.sh)"

titulo "1. Instalación de Rclone"
ejecutar apt-get install -y rclone
ejecutar rclone version

titulo "2. Credenciales de Backblaze B2"
read -r -p "keyID (Application Key ID): " KEY_ID
read -r -s -p "applicationKey (no se muestra): " APP_KEY; echo
read -r -p "Nombre del bucket privado: " BUCKET
[[ -n "$KEY_ID" && -n "$APP_KEY" && -n "$BUCKET" ]] || morir "Faltan datos"
[[ "$BUCKET" =~ ^[a-zA-Z0-9-]{6,63}$ ]] || morir "Nombre de bucket inválido"

install -d -m 700 /root/.config/rclone
touch "$RCLONE_CONF"
chmod 600 "$RCLONE_CONF"
rclone config delete "$REMOTO" 2> /dev/null || true
cat >> "$RCLONE_CONF" <<EOF

[$REMOTO]
type = b2
account = $KEY_ID
key = $APP_KEY
hard_delete = true
EOF
unset APP_KEY
ok "Remoto '$REMOTO' guardado en $RCLONE_CONF (600 root:root)"

titulo "3. Verificación del acceso al bucket"
DEST="$REMOTO:$BUCKET/miproyecto"
PRUEBA=$(mktemp)
echo "Prueba de conexión desde $(hostname) — $(date)" > "$PRUEBA"
if ! ejecutar rclone copyto "$PRUEBA" "$DEST/.prueba_conexion.txt"; then
    rm -f "$PRUEBA"
    morir "No se pudo escribir en el bucket. Revisá el keyID, la applicationKey, el nombre del bucket y que la clave tenga permiso de lectura y escritura. Luego volvé a ejecutar este script."
fi
ejecutar rclone lsf "$DEST/"
ejecutar rclone cat "$DEST/.prueba_conexion.txt"
ejecutar rclone deletefile "$DEST/.prueba_conexion.txt"
rm -f "$PRUEBA"
ok "Lectura, escritura y borrado en el bucket funcionan"

titulo "4. Integración con backup.sh"
sed -i -E "s|^RCLONE_DEST=.*|RCLONE_DEST=\"$DEST\"|" "$CONF"
grep -q '^RCLONE_DEST=' "$CONF" || echo "RCLONE_DEST=\"$DEST\"" >> "$CONF"
# Ruta explícita: con sudo, HOME puede no ser /root
sed -i -E '/^RCLONE_CONFIG_FILE=/d' "$CONF"
echo "RCLONE_CONFIG_FILE=\"$RCLONE_CONF\"" >> "$CONF"
grep -E '^(RCLONE_DEST|RCLONE_CONFIG_FILE|KEEP_CLOUD)=' "$CONF" | sed 's/^/    /'

titulo "5. Respaldo completo de prueba (local + nube)"
ejecutar /usr/local/bin/backup.sh
echo
ejecutar rclone ls "$DEST/"
echo
ok "Registro de transferencias:  $RESPALDOS_DIR/logs/backup.log  y  $RESPALDOS_DIR/logs/rclone.log"
ok "Probar la recuperación:     sudo restore.sh --nube ultimo --solo-verificar"
