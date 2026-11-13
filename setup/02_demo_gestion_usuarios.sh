#!/usr/bin/env bash
# =============================================================================
#  PARTE 2 — Demostración: crear, modificar, bloquear y eliminar un usuario
#
#  Uso:  sudo bash setup/02_demo_gestion_usuarios.sh [--sin-pausa]
#
#  Trabaja con un usuario temporal "practicante" que al final se elimina.
#  Cada comando se muestra antes de ejecutarse para explicarlo en clase.
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root

U="practicante"
PAUSA=1
[[ "${1:-}" == "--sin-pausa" ]] && PAUSA=0
pausa() { [[ $PAUSA -eq 1 ]] && read -r -p "  [Enter para continuar] " _ || true; }

id "$U" &> /dev/null && { aviso "$U ya existía: se elimina para empezar de cero"; userdel -r "$U" 2> /dev/null || true; }

titulo "1. CREAR un usuario"
ejecutar useradd -m -s /bin/bash -c "Usuario temporal de prueba" -G "$GRUPO_DEV" "$U"
echo "  (se asigna la contraseña con chpasswd para no pedirla por teclado; en clase se puede usar: passwd $U)"
printf '%s:%s\n' "$U" "Practica.$(date +%Y)" | chpasswd
ejecutar id "$U"
ejecutar getent passwd "$U"
ejecutar ls -ld "/home/$U"
pausa

titulo "2. MODIFICAR el usuario"
ejecutar usermod -c "Practicante - Área de respaldos" "$U"      # comentario / nombre completo
ejecutar usermod -aG "$GRUPO_BACKUP" "$U"                         # agregar a un grupo secundario
ejecutar usermod -s /bin/sh "$U"                                   # cambiar el intérprete de comandos
ejecutar chage -E "$(date -d '+30 days' +%F)" "$U"                 # la cuenta vence en 30 días
ejecutar id "$U"
ejecutar getent passwd "$U"
ejecutar chage -l "$U"
pausa

titulo "3. BLOQUEAR el usuario"
ejecutar usermod -L "$U"            # bloquea la contraseña (agrega "!" en /etc/shadow)
ejecutar usermod -e 1 "$U"          # además expira la cuenta: tampoco entra con clave SSH
ejecutar passwd -S "$U"             # la "L" indica que está bloqueado
echo "  /etc/shadow: $(getent shadow "$U" | cut -c1-25)…"
echo "  Prueba de ingreso por SSH (debe fallar):"
if command -v sshpass > /dev/null; then
    sshpass -p "Practica.$(date +%Y)" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$U@localhost" true 2>&1 | tail -1 || true
else
    echo "    probar manualmente desde otra terminal:  ssh $U@localhost   → Permission denied"
fi
pausa

titulo "4. DESBLOQUEAR el usuario"
ejecutar usermod -U "$U"
ejecutar usermod -e "" "$U"
ejecutar passwd -S "$U"             # la "P" indica contraseña utilizable
pausa

titulo "5. ELIMINAR el usuario"
ejecutar userdel -r "$U" 2> /dev/null   # -r borra también /home/practicante y su buzón
ejecutar getent passwd "$U" || true
if id "$U" &> /dev/null; then error "El usuario sigue existiendo"; else ok "El usuario $U ya no existe"; fi
if [[ -d "/home/$U" ]]; then error "/home/$U sigue existiendo"; else ok "Su directorio /home/$U también se eliminó"; fi
