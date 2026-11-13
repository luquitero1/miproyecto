#!/usr/bin/env bash
set -euo pipefail

URL="${1:?Uso: sudo bash $0 https://github.com/USUARIO/miproyecto.git}"
APP_DIR=/var/www/miproyecto

[[ -d "$APP_DIR/.git" ]] || git clone --branch main "$URL" "$APP_DIR"

chown -R root:desarrolladores "$APP_DIR"
chmod -R g+rwX,o+rX,o-w "$APP_DIR"
find "$APP_DIR" -type d -exec chmod g+s {} +
chown -R root:root "$APP_DIR/.git"
chmod -R go-w "$APP_DIR/.git"

install -m 755 "$APP_DIR"/scripts/{deploy,backup,restore}.sh /usr/local/bin/
ls -la "$APP_DIR"
