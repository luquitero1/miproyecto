#!/usr/bin/env bash
set -euo pipefail

NOMBRE="${1:-centro-computos}"
hostnamectl set-hostname "$NOMBRE"
sed -i '/^127\.0\.1\.1/d' /etc/hosts
printf '127.0.1.1\t%s\n' "$NOMBRE" >> /etc/hosts

ip -brief address
ip route show default
ping -c 3 8.8.8.8
getent hosts deb.debian.org

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o Dpkg::Options::=--force-confold full-upgrade
apt-get -y install sudo curl vim htop tree rsync acl cron openssh-server

echo "PermitRootLogin no" > /etc/ssh/sshd_config.d/centro-computos.conf
systemctl enable --now ssh cron
systemctl restart ssh

mkdir -p /srv/administracion /srv/proyectos /srv/compartido /srv/respaldos/{local,logs,restauracion} /var/log/miproyecto
tree -d -L 2 /srv

hostnamectl
uptime
free -h
df -h /
