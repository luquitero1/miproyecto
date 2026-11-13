#!/usr/bin/env bash
# =============================================================================
#  PARTE 4 — Base de datos de la aplicación
#
#  Uso:  sudo bash setup/05_base_datos.sh [--sin-datos-ejemplo]
#
#  - Crea la base "miproyecto" y el usuario "miproyecto_app" con privilegios
#    mínimos (SELECT, INSERT, UPDATE, DELETE) y contraseña aleatoria.
#  - Crea las tablas (sql/schema.sql) y carga datos de ejemplo si está vacía.
#  - Guarda las credenciales en /etc/miproyecto/config.php
#    (fuera del repositorio y de la carpeta pública: nunca llegan a GitHub).
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

CARGAR_EJEMPLO=1
[[ "${1:-}" == "--sin-datos-ejemplo" ]] && CARGAR_EJEMPLO=0
SQL_DIR="$APP_DIR/sql"
[[ -f "$SQL_DIR/schema.sql" ]] || SQL_DIR="$REPO_DIR/sql"
systemctl is-active --quiet mariadb || morir "MariaDB no está activo (sudo systemctl start mariadb)"
CONFIG_PHP="$CONFIG_DIR/config.php"

titulo "1. Credenciales"
if [[ -f "$CONFIG_PHP" ]]; then
    CLAVE=$(php -r '$c = require $argv[1]; echo $c["db"]["pass"];' "$CONFIG_PHP")
    ok "Se reutiliza la contraseña existente de $CONFIG_PHP"
else
    CLAVE=$(clave_aleatoria)
    ok "Contraseña aleatoria generada para $DB_USER"
fi

titulo "2. Base de datos y usuario"
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$CLAVE';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$CLAVE';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
ok "Base '$DB_NAME' y usuario '$DB_USER'@'localhost' listos"
mariadb -e "SHOW GRANTS FOR '$DB_USER'@'localhost'" | tail -n +2 | sed -E 's/IDENTIFIED BY PASSWORD .*//; s/^/    /'

titulo "3. Tablas"
ejecutar mariadb "$DB_NAME" < "$SQL_DIR/schema.sql"
TOTAL=$(mariadb -N "$DB_NAME" -e 'SELECT COUNT(*) FROM equipos')
if [[ $CARGAR_EJEMPLO -eq 1 && $TOTAL -eq 0 ]]; then
    mariadb "$DB_NAME" < "$SQL_DIR/datos_ejemplo.sql"
    ok "Datos de ejemplo cargados"
fi
mariadb "$DB_NAME" -e 'SHOW TABLES; SELECT COUNT(*) AS equipos_registrados FROM equipos;' | sed 's/^/    /'

titulo "4. Archivo de configuración de la aplicación"
install -d -o root -g www-data -m 750 "$CONFIG_DIR"
umask 027
cat > "$CONFIG_PHP" <<EOF
<?php
// Generado por setup/05_base_datos.sh el $(date '+%Y-%m-%d %H:%M').
// Contiene credenciales: NO copiar al repositorio. Permisos 640 root:www-data.
return [
    'db' => [
        'host'   => 'localhost',
        'port'   => 3306,
        'socket' => '/run/mysqld/mysqld.sock',
        'name'   => '$DB_NAME',
        'user'   => '$DB_USER',
        'pass'   => '$CLAVE',
    ],
    'debug' => false,
];
EOF
chown root:www-data "$CONFIG_PHP"
chmod 640 "$CONFIG_PHP"
stat -c '  %A  %U:%G  %n' "$CONFIG_DIR" "$CONFIG_PHP"

titulo "5. Prueba de conexión con el usuario de la aplicación"
if MYSQL_PWD="$CLAVE" mariadb -u "$DB_USER" "$DB_NAME" -N -e 'SELECT CONCAT("  Conectado como ", CURRENT_USER(), " — registros: ", COUNT(*)) FROM equipos'; then
    ok "La aplicación puede conectarse a la base de datos"
else
    morir "No se pudo conectar con $DB_USER"
fi
