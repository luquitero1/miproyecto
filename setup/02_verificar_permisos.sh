#!/usr/bin/env bash
# =============================================================================
#  PARTE 2 — Comprobar que cada usuario sólo accede a los recursos autorizados
#
#  Uso:  sudo bash setup/02_verificar_permisos.sh
#
#  Ejecuta pruebas reales de lectura y escritura como cada usuario (runuser)
#  y compara el resultado con lo esperado.
#     RW = lectura y escritura · R = sólo lectura · - = sin acceso
# =============================================================================
source "$(dirname "$0")/lib.sh"
requiere_root
trap - ERR
set +e

USUARIOS=(ana carla elena)                         # uno de cada grupo
ROLES=(administradores desarrolladores respaldos)
for u in "${USUARIOS[@]}"; do id "$u" &> /dev/null || morir "Falta el usuario $u (ejecutar 02_usuarios_grupos.sh)"; done

# recurso | esperado para ana | carla | elena
RECURSOS=(
    "/srv/administracion|RW|-|-"
    "/srv/proyectos|-|RW|-"
    "$RESPALDOS_DIR/local|-|-|RW"
    "/srv/compartido|RW|RW|RW"
    "$APP_DIR/public|R|RW|R"
    "$CONFIG_DIR/config.php|-|-|-"
    "/home/carla|-|RW|-"
    "/etc/shadow|-|-|-"
)

# Devuelve RW, R o - según lo que el usuario realmente pueda hacer.
probar() {
    local u="$1" ruta="$2" lee=0 escribe=0
    if [[ -d "$ruta" ]]; then
        runuser -u "$u" -- ls "$ruta" &> /dev/null && lee=1
        local prueba="$ruta/.prueba_permiso_$u"
        if runuser -u "$u" -- touch "$prueba" &> /dev/null; then escribe=1; rm -f "$prueba"; fi
    else
        runuser -u "$u" -- cat "$ruta" &> /dev/null && lee=1
        runuser -u "$u" -- test -w "$ruta" && escribe=1
    fi
    if [[ $lee -eq 1 && $escribe -eq 1 ]]; then echo RW
    elif [[ $lee -eq 1 ]]; then echo R
    elif [[ $escribe -eq 1 ]]; then echo W
    else echo -; fi
}

titulo "Matriz de accesos (resultado real / esperado)"
printf '%-34s' "Recurso"
for i in "${!USUARIOS[@]}"; do printf '%-18s' "${USUARIOS[$i]} (${ROLES[$i]:0:5}.)"; done
echo
ERRORES=0
for fila in "${RECURSOS[@]}"; do
    IFS='|' read -r ruta e1 e2 e3 <<< "$fila"
    esperados=("$e1" "$e2" "$e3")
    if [[ ! -e "$ruta" ]]; then printf '%-34s (no existe todavía)\n' "$ruta"; continue; fi
    printf '%-34s' "$ruta"
    for i in "${!USUARIOS[@]}"; do
        real=$(probar "${USUARIOS[$i]}" "$ruta")
        if [[ "$real" == "${esperados[$i]}" ]]; then
            printf '%s%-20s%s' "$C_VERDE" "✔ $real" "$C_FIN"
        else
            printf '%s%-20s%s' "$C_ROJO" "✘ $real (esp. ${esperados[$i]})" "$C_FIN"
            ERRORES=$((ERRORES + 1))
        fi
    done
    echo
done

titulo "Permisos de sudo de cada usuario"
for u in "${USUARIOS[@]}"; do
    echo "  $u:"
    sudo -l -U "$u" 2> /dev/null | sed -n '/puede ejecutar\|may run/,$p' | tail -n +2 | sed 's/^ */      /'
done

titulo "Resultado"
if [[ $ERRORES -eq 0 ]]; then
    ok "Todos los accesos coinciden con lo autorizado."
else
    error "$ERRORES acceso(s) no coinciden con lo esperado."
    exit 1
fi
