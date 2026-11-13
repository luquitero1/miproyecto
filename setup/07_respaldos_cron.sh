#!/usr/bin/env bash
set -euo pipefail

install -m 755 /var/www/miproyecto/scripts/backup.sh /usr/local/bin/backup.sh

{
    crontab -l 2> /dev/null | grep -v backup.sh || true
    echo "0 0 * * 6 /usr/local/bin/backup.sh --semanal >> /srv/respaldos/logs/cron.log 2>&1"
} | crontab -
crontab -l

/usr/local/bin/backup.sh
ls -lh /srv/respaldos/local
