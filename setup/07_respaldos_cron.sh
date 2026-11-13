#!/usr/bin/env bash
# =============================================================================
#  PARTE 7 — Respaldos locales automáticos
#
#  Uso:  sudo bash setup/07_respaldos_cron.sh
#
#  - Prepara /srv/respaldos (fuera de la carpeta pública de Apache)
#  - Crea /etc/miproyecto/backup.conf
#  - Instala backup.sh en /usr/local/bin
#  - Programa el respaldo en el crontab de root:  0 0 * * 6  (sábados 00:00)
#  - Ejecuta un respaldo manual de prueba
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

CONF="$CONFIG_DIR/backup.conf"
LINEA_CRON="0 0 * * 6 /usr/local/bin/backup.sh --semanal >> $RESPALDOS_DIR/logs/cron.log 2>&1"

titulo "1. Directorios de respaldo"
for d in "$RESPALDOS_DIR" "$RESPALDOS_DIR/local" "$RESPALDOS_DIR/logs" "$RESPALDOS_DIR/restauracion"; do
    install -d -o root -g "$GRUPO_BACKUP" -m 2770 "$d"
    stat -c '  %A  %U:%G  %n' "$d"
done

titulo "2. Configuración de los respaldos"
install -d -o root -g www-data -m 750 "$CONFIG_DIR"
if [[ -f "$CONF" ]]; then
    ok "$CONF ya existe (se conserva)"
else
    cat > "$CONF" <<EOF
# Configuración de backup.sh y restore.sh (la lee root; no contiene contraseñas).
APP_DIR="$APP_DIR"
CONFIG_DIR="$CONFIG_DIR"
VHOST_FILE="/etc/apache2/sites-available/$DOMINIO.conf"
DB_NAME="$DB_NAME"
BACKUP_DIR="$RESPALDOS_DIR/local"
LOG_DIR="$RESPALDOS_DIR/logs"
RESTORE_DIR="$RESPALDOS_DIR/restauracion"
BACKUP_GROUP="$GRUPO_BACKUP"

# Cantidad de respaldos a conservar de cada tipo (4 semanales = 1 mes)
KEEP_LOCAL=4
KEEP_CLOUD=4

# Destino en la nube (lo completa 08_backblaze_rclone.sh). Vacío = sólo local.
RCLONE_DEST=""
EOF
    ok "$CONF creado"
fi
chown root:root "$CONF"
chmod 644 "$CONF"

titulo "3. Scripts"
if [[ -f "$APP_DIR/scripts/backup.sh" ]]; then instalar_scripts "$APP_DIR/scripts"; else instalar_scripts "$REPO_DIR/scripts"; fi

titulo "4. Tarea programada (crontab de root)"
( crontab -l 2> /dev/null | grep -v -e '/usr/local/bin/backup.sh' -e '^# Respaldo semanal de miproyecto' || true
  echo "# Respaldo semanal de miproyecto.com: sábados a las 00:00 (local + Backblaze B2)"
  echo "$LINEA_CRON" ) | crontab -
ejecutar crontab -l
ok "Expresión 0 0 * * 6 → minuto 0, hora 0, cualquier día del mes, cualquier mes, día de semana 6 (sábado)"
systemctl is-active --quiet cron && ok "El servicio cron está activo" || aviso "cron no está activo: sudo systemctl enable --now cron"

titulo "5. Ejecución manual de prueba"
ejecutar /usr/local/bin/backup.sh --solo-local
echo
ejecutar ls -lh "$RESPALDOS_DIR/local"
echo
paso "Contenido del último respaldo:"
ULTIMO=$(ls -1 "$RESPALDOS_DIR"/local/*.tar.gz | sort | tail -n 1)
tar -tzf "$ULTIMO" | grep -E '^(basedatos\.sql|INFO\.txt|var/www/[^/]+/(public/)?|etc/.*[^/])$' | sed 's/^/    /'
echo
ok "Registro de ejecuciones:  $RESPALDOS_DIR/logs/backup.log"
