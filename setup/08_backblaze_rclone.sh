#!/usr/bin/env bash
set -euo pipefail

apt-get -y install rclone

read -r -p "keyID: " KEY_ID
read -r -s -p "applicationKey: " APP_KEY
echo
read -r -p "Nombre del bucket privado: " BUCKET

install -d -m 700 /root/.config/rclone
umask 077
cat > /root/.config/rclone/rclone.conf <<EOF
[b2]
type = b2
account = $KEY_ID
key = $APP_KEY
hard_delete = true
EOF
umask 022

rclone --config /root/.config/rclone/rclone.conf lsf "b2:$BUCKET"
echo "RCLONE_DEST=\"b2:$BUCKET/miproyecto\"" > /etc/miproyecto/backup.conf

/usr/local/bin/backup.sh
rclone --config /root/.config/rclone/rclone.conf ls "b2:$BUCKET/miproyecto"
