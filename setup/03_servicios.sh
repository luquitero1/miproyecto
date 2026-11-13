#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install apache2 php libapache2-mod-php php-mysql mariadb-server git openssh-server curl

systemctl enable --now apache2 mariadb ssh cron
systemctl restart apache2 mariadb
systemctl --no-pager status apache2 mariadb ssh cron | grep -E '●|Active:'

curl -s -o /dev/null -w "Apache: HTTP %{http_code}\n" http://localhost/
php -v | head -n 1
mariadb -e 'SELECT VERSION()'
git --version
journalctl -p err -b --no-pager | tail -n 20
