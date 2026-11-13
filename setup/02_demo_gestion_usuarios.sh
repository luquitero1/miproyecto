#!/usr/bin/env bash
set -euo pipefail
set -x

useradd -m -s /bin/bash -c "Usuario de prueba" -G desarrolladores practicante
echo "practicante:Practica.2026" | chpasswd
id practicante

usermod -c "Practicante de respaldos" -aG respaldos -s /bin/sh practicante
id practicante
getent passwd practicante

usermod -L practicante
passwd -S practicante

usermod -U practicante
passwd -S practicante

userdel -r practicante
id practicante || true
