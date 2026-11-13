#!/usr/bin/env bash
# =============================================================================
#  PARTE 3 — Instalación y administración de servicios
#
#  Uso:  sudo bash setup/03_servicios.sh
#
#  Instala directamente en el sistema (sin Docker): Apache2, PHP, MariaDB,
#  Git y OpenSSH Server; los habilita al inicio y verifica su funcionamiento.
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root
export DEBIAN_FRONTEND=noninteractive

titulo "1. Instalación de paquetes"
PAQUETES=(apache2 php libapache2-mod-php php-cli php-mysql php-mbstring
          mariadb-server mariadb-client git openssh-server curl)
ejecutar apt-get update
ejecutar apt-get install -y "${PAQUETES[@]}"

# --- Docker / puerto 3306 -------------------------------------------------------
titulo "2. Comprobación de conflictos"
if command -v docker > /dev/null && [[ -n "$(docker ps -q 2> /dev/null)" ]]; then
    aviso "Hay contenedores Docker en ejecución (el práctico no permite Docker):"
    docker ps --format '      {{.Names}}  ({{.Image}})  {{.Ports}}'
    aviso "Para la presentación conviene detenerlos:  sudo docker stop \$(sudo docker ps -q)"
fi
if ! systemctl is-active --quiet mariadb && ss -Htln 'sport = :3306' | grep -q .; then
    aviso "El puerto 3306 está ocupado por otro proceso:"
    ss -Htlnp 'sport = :3306' | sed 's/^/      /'
    if [[ "${MARIADB_PUERTO_ALTERNATIVO:-1}" == 1 ]]; then
        cat > /etc/mysql/mariadb.conf.d/60-centro-computos.cnf <<'EOF'
# El puerto 3306 estaba ocupado (contenedor Docker). La aplicación se conecta
# por el socket /run/mysqld/mysqld.sock, así que el puerto TCP no la afecta.
# Si se libera el 3306, se puede borrar este archivo y reiniciar mariadb.
[mysqld]
port = 3307
EOF
        aviso "MariaDB se configuró en el puerto 3307 (/etc/mysql/mariadb.conf.d/60-centro-computos.cnf)"
    fi
else
    ok "Sin conflictos de puertos"
fi

# --- Inicio automático y arranque -------------------------------------------------
titulo "3. Habilitar el inicio automático e iniciar servicios"
for s in apache2 mariadb ssh cron; do
    ejecutar systemctl enable --now "$s"
done

# --- Configuración básica ------------------------------------------------------
titulo "4. Configuración básica"
# Evita la advertencia AH00558 ("Could not reliably determine the server's fully qualified domain name")
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
ejecutar a2enconf -q servername
ejecutar a2enmod -q headers
# Oculta la versión de Apache y del sistema en las respuestas
sed -i -E 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
ejecutar apache2ctl configtest
ejecutar systemctl reload apache2

paso "Endurecimiento de MariaDB (equivalente a mariadb-secure-installation)"
mariadb <<'SQL'
DELETE FROM mysql.global_priv WHERE User = '';
DELETE FROM mysql.global_priv WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db = 'test' OR Db = 'test\\_%';
FLUSH PRIVILEGES;
SQL
ok "Sin usuarios anónimos, sin base 'test', root sólo local (autenticación por socket)"

# --- Verificación --------------------------------------------------------------------
titulo "5. Estado de los servicios"
printf '  %-10s %-10s %-10s\n' SERVICIO ACTIVO "AL INICIO"
for s in apache2 mariadb ssh cron; do
    printf '  %-10s %-10s %-10s\n' "$s" "$(systemctl is-active "$s")" "$(systemctl is-enabled "$s")"
done

titulo "6. Verificación de funcionamiento"
codigo=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/)
[[ "$codigo" == 200 ]] && ok "Apache responde en http://localhost (HTTP $codigo)" || aviso "Apache respondió HTTP $codigo"
ok "PHP: $(php -r 'echo PHP_VERSION;') — módulo Apache: $(apache2ctl -M 2> /dev/null | grep -o 'php[0-9_]*_module' || echo 'NO CARGADO')"
ok "MariaDB: $(mariadb -N -e 'SELECT VERSION()')"
ok "Git: $(git --version)"
ok "SSH: $(ssh -V 2>&1)"

titulo "Comandos de administración (para la demostración)"
cat <<'EOF'
  sudo systemctl status apache2          # estado
  sudo systemctl stop apache2            # detener
  sudo systemctl start apache2           # iniciar
  sudo systemctl restart apache2         # reiniciar
  sudo systemctl reload apache2          # recargar configuración sin cortar conexiones
  sudo systemctl is-enabled mariadb      # ¿arranca con el sistema?
  sudo journalctl -u apache2 -n 30       # registros del servicio
  sudo journalctl -p err -b              # errores desde el último arranque
  sudo tail -f /var/log/apache2/error.log
  sudo journalctl -u mariadb -n 30       # registros de MariaDB
EOF
