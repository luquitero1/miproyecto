#!/usr/bin/env bash
set -euo pipefail

cat > /etc/apache2/sites-available/miproyecto.com.conf <<'EOF'
<VirtualHost *:80>
    ServerName miproyecto.com
    ServerAlias www.miproyecto.com
    DocumentRoot /var/www/miproyecto/public
    <Directory /var/www/miproyecto/public>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/miproyecto_error.log
    CustomLog ${APACHE_LOG_DIR}/miproyecto_access.log combined
</VirtualHost>
EOF
a2ensite miproyecto.com.conf
apache2ctl configtest
systemctl reload apache2

grep -q 'miproyecto.com' /etc/hosts || printf '127.0.0.1\tmiproyecto.com www.miproyecto.com\n' >> /etc/hosts
grep miproyecto.com /etc/hosts

curl -s -o /dev/null -w "http://miproyecto.com -> HTTP %{http_code}\n" http://miproyecto.com/
curl -s -o /dev/null -w "http://miproyecto.com/estado.php -> HTTP %{http_code}\n" http://miproyecto.com/estado.php
echo "Desde otro equipo, agregar a su archivo hosts: $(hostname -I | awk '{print $1}') miproyecto.com"
