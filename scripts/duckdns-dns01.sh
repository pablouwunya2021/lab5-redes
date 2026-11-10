#!/usr/bin/env bash
# Prueba del reto DNS-01 con DuckDNS desde el Mac, ANTES de tocar certbot (docs/samuel-inicio.md, A2).
#   1. Fija la IP del subdominio en WEB_IP (192.168.56.11), como pide la guía 12.3.
#   2. Publica un TXT de prueba y espera a verlo en <sub>.duckdns.org y en
#      _acme-challenge.<sub>.duckdns.org (que es el nombre que consulta Let's Encrypt).
#   3. Borra el TXT (también si se corta con Ctrl-C).
# El token se lee de secrets/duckdns.token (ignorado por git). No se imprime ni va en la
# línea de comandos: se le pasa a curl por stdin (-K -), así no aparece en `ps`.
# Uso: ./scripts/duckdns-dns01.sh [subdominio]     (por defecto, DOMINIO de .env)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
[ -f .env ] && . ./.env
WEB_IP=${WEB_IP:-192.168.56.11}
TOKEN_FILE=${DUCKDNS_TOKEN_FILE:-secrets/duckdns.token}   # la variable solo se usa para probar el script
ESPERA_MAX=90   # segundos para que el TXT aparezca en cada servidor DNS

SUB=${1:-${DOMINIO:-}}
SUB=${SUB%.duckdns.org}
if [ -z "$SUB" ]; then
  echo "Falta el subdominio: ./scripts/duckdns-dns01.sh lab5uvg  (o DOMINIO en .env)"; exit 2
fi
if ! [[ "$SUB" =~ ^[a-z0-9-]+$ ]]; then
  echo "Subdominio inválido: '$SUB' (solo a-z, 0-9 y guiones, sin .duckdns.org)"; exit 2
fi
if [ ! -s "$TOKEN_FILE" ]; then
  echo "No existe $TOKEN_FILE. En la página de duckdns.org haz Cmd+A, Cmd+C y corre:"
  echo "  pbpaste | grep -oE '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}' | head -1 > $TOKEN_FILE && chmod 600 $TOKEN_FILE"
  exit 2
fi
chmod 600 "$TOKEN_FILE"
TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE")
[[ "$TOKEN" =~ ^[0-9a-f-]{36}$ ]] || echo "[AVISO] El token no tiene el formato habitual de DuckDNS (36 caracteres); sigo igual."

DOM="$SUB.duckdns.org"

# Llama a la API de DuckDNS. $1 = parámetros extra. Devuelve la respuesta (verbose, sin token).
duck() {
  printf 'url = "https://www.duckdns.org/update?domains=%s&token=%s&%s&verbose=true"\n' \
    "$SUB" "$TOKEN" "$1" | curl -s --max-time 20 -K -
}
primera() { printf '%s\n' "$1" | head -1; }

# ¿El servidor $2 devuelve el TXT $3 para el nombre $1?
tiene_txt() { dig +short +time=3 +tries=1 TXT "$1" @"$2" 2>/dev/null | tr -d '"' | grep -qxF "$3"; }

echo "== 1. IP de $DOM -> $WEB_IP"
r=$(duck "ip=$WEB_IP")
printf '%s\n' "$r" | sed 's/^/     /'
if [ "$(primera "$r")" != OK ]; then
  echo "DuckDNS respondió '$(primera "$r")': token incorrecto o el subdominio '$SUB' no está creado en esta cuenta."
  exit 1
fi

VAL="lab5-prueba-$(date +%s)"
limpiar() {
  echo "== 4. Borrando el TXT de prueba"
  printf '%s\n' "$(duck "txt=removed&clear=true")" | sed 's/^/     /'
}
trap limpiar EXIT
trap 'exit 130' INT TERM

echo "== 2. Publicando TXT de prueba: $VAL"
r=$(duck "txt=$VAL")
printf '%s\n' "$r" | sed 's/^/     /'
[ "$(primera "$r")" = OK ] || { echo "No se pudo fijar el TXT."; exit 1; }

echo "== 3. Esperando a verlo en DNS (máx ${ESPERA_MAX} s por servidor)"
PASS=0; FAIL=0
for nombre in "$DOM" "_acme-challenge.$DOM"; do
  for srv in ns1.duckdns.org 8.8.8.8 1.1.1.1; do
    t=0
    until tiene_txt "$nombre" "$srv" "$VAL"; do
      [ "$t" -ge "$ESPERA_MAX" ] && break
      sleep 5; t=$((t + 5))
    done
    if tiene_txt "$nombre" "$srv" "$VAL"; then
      printf "  [PASA]  %-40s @%-16s (%2d s)\n" "$nombre" "$srv" "$t"; PASS=$((PASS + 1))
    else
      printf "  [FALLA] %-40s @%-16s no lo ve tras %d s\n" "$nombre" "$srv" "$t"; FAIL=$((FAIL + 1))
    fi
  done
done

a=$(dig +short A "$DOM" @ns1.duckdns.org | tr '\n' ' ')
echo "     Registro A de $DOM en DuckDNS: ${a:-(vacío)}"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Resultado: DNS-01 VIABLE. Let's Encrypt verá el TXT en _acme-challenge.$DOM ($PASS/$PASS consultas)."
  echo "Siguiente: anotar DOMINIO=$DOM en .env y docs/00-variables.md."
else
  echo "Resultado: $FAIL consultas fallaron. Si falla _acme-challenge en ns1.duckdns.org, DuckDNS no sirve:"
  echo "avisar al equipo (plan B: dominio propio con DNS en Cloudflare). Si solo falla 8.8.8.8/1.1.1.1, es caché: reintentar."
  exit 1
fi
