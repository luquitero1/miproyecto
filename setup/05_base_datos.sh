#!/usr/bin/env bash
set -euo pipefail

CONFIG=/etc/miproyecto/config.php
if [[ -f "$CONFIG" ]]; then
    CLAVE=$(php -r '$c = require $argv[1]; echo $c["db"]["pass"];' "$CONFIG")
else
    CLAVE=$(head -c 18 /dev/urandom | base64 | tr -d '+/=')
fi

mariadb <<SQL
CREATE DATABASE IF NOT EXISTS miproyecto CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'miproyecto_app'@'localhost' IDENTIFIED BY '$CLAVE';
ALTER USER 'miproyecto_app'@'localhost' IDENTIFIED BY '$CLAVE';
GRANT SELECT, INSERT, UPDATE, DELETE ON miproyecto.* TO 'miproyecto_app'@'localhost';
SQL
mariadb miproyecto < /var/www/miproyecto/sql/schema.sql

install -d -o root -g www-data -m 750 /etc/miproyecto
cat > "$CONFIG" <<EOF
<?php
return [
    'db' => [
        'socket' => '/run/mysqld/mysqld.sock',
        'name'   => 'miproyecto',
        'user'   => 'miproyecto_app',
        'pass'   => '$CLAVE',
    ],
];
EOF
chown root:www-data "$CONFIG"
chmod 640 "$CONFIG"

MYSQL_PWD="$CLAVE" mariadb -u miproyecto_app miproyecto -e 'SHOW TABLES'
