#!/usr/bin/env bash
# =============================================================================
#  PARTE 5 — VirtualHost de Apache para http://miproyecto.com
#
#  Uso:  sudo bash setup/06_apache_vhost.sh
#
#  - Crea /etc/apache2/sites-available/miproyecto.com.conf
#  - Lo habilita (a2ensite), verifica la sintaxis y recarga Apache
#  - Agrega miproyecto.com al archivo /etc/hosts de este equipo
#  - Comprueba que el dominio, PHP y la base de datos respondan
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

VHOST="/etc/apache2/sites-available/$DOMINIO.conf"
[[ -d "$APP_DIR/public" ]] || morir "No existe $APP_DIR/public (ejecutar antes 04_clonar_repositorio.sh)"

titulo "1. VirtualHost"
cat > "$VHOST" <<EOF
# VirtualHost de la aplicación "Inventario de Equipos"
<VirtualHost *:80>
    ServerName $DOMINIO
    ServerAlias www.$DOMINIO
    ServerAdmin webmaster@$DOMINIO

    # Sólo la carpeta public/ es accesible desde la web;
    # src/, sql/, scripts/ y .git quedan fuera del alcance del navegador.
    DocumentRoot $APP_DIR/public

    <Directory $APP_DIR/public>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
        DirectoryIndex index.php
    </Directory>

    # Defensa adicional: nunca servir archivos ocultos (.git, .env, .htaccess...)
    <LocationMatch "/\.">
        Require all denied
    </LocationMatch>

    <IfModule mod_headers.c>
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "SAMEORIGIN"
        Header always set Referrer-Policy "same-origin"
    </IfModule>

    ErrorLog \${APACHE_LOG_DIR}/miproyecto_error.log
    CustomLog \${APACHE_LOG_DIR}/miproyecto_access.log combined
</VirtualHost>
EOF
ok "$VHOST creado"
ejecutar a2ensite "$DOMINIO.conf"
ejecutar apache2ctl configtest
ejecutar systemctl reload apache2
apache2ctl -S 2>&1 | grep -E "namevhost|port 80" | sed "s/^/    /" || true

titulo "2. Archivo hosts"
if grep -qE "^[^#]*\s$DOMINIO(\s|$)" /etc/hosts; then
    ok "/etc/hosts ya contiene $DOMINIO"
else
    printf '127.0.0.1\t%s www.%s\n' "$DOMINIO" "$DOMINIO" >> /etc/hosts
    ok "Agregado a /etc/hosts:  127.0.0.1  $DOMINIO www.$DOMINIO"
fi
grep -E "$DOMINIO" /etc/hosts | sed 's/^/    /'

titulo "3. Verificación"
for ruta in / /estado.php /assets/estilos.css; do
    codigo=$(curl -s -o /dev/null -w '%{http_code}' "http://$DOMINIO$ruta")
    if [[ "$codigo" == 200 ]]; then ok "http://$DOMINIO$ruta → HTTP $codigo"; else error "http://$DOMINIO$ruta → HTTP $codigo"; fi
done
for ruta in /../config/config.example.php /.git/HEAD; do
    codigo=$(curl -s -o /dev/null -w '%{http_code}' --path-as-is "http://$DOMINIO$ruta")
    if [[ "$codigo" != 200 ]]; then ok "$ruta no es accesible (HTTP $codigo)"; else error "$ruta ES accesible"; fi
done
curl -s "http://$DOMINIO/estado.php" | grep -oE 'Todo funcionando|Hay problemas' | head -1 | sed 's/^/  Estado de la aplicación: /'

IP=$(hostname -I | awk '{print $1}')
titulo "Acceso desde otro equipo (por ejemplo, el anfitrión de la máquina virtual)"
cat <<EOF
  Agregar esta línea al archivo hosts de ESE equipo:
      $IP    $DOMINIO www.$DOMINIO

  • Linux / macOS:  /etc/hosts   (sudo nano /etc/hosts)
  • Windows:        C:\\Windows\\System32\\drivers\\etc\\hosts  (Bloc de notas como administrador)
  Luego abrir en el navegador:  http://$DOMINIO   (escribir http:// explícitamente)
EOF
