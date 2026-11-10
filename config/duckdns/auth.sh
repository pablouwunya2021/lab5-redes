#!/bin/bash
# Hook de certbot (--manual-auth-hook) para el reto DNS-01 con DuckDNS.
# Va en web01 como /etc/letsencrypt/duckdns/auth.sh (root:root, 700).
# El token NO va aquí: se lee de /etc/letsencrypt/duckdns/duckdns.token (root:root, 600),
# así este archivo puede vivir en el repo. certbot define CERTBOT_DOMAIN y CERTBOT_VALIDATION.
# DUCKDNS_TOKEN_FILE solo sirve para probarlo fuera de web01 (certbot no la define).
# Probado el 10/11 en el Mac con el dominio real: publica el TXT y lo ve en el DNS.
set -u
TOKEN_FILE=${DUCKDNS_TOKEN_FILE:-/etc/letsencrypt/duckdns/duckdns.token}
TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE") || exit 1
SUB="${CERTBOT_DOMAIN%.duckdns.org}"

r=$(printf 'url = "https://www.duckdns.org/update?domains=%s&token=%s&txt=%s&verbose=true"\n' \
      "$SUB" "$TOKEN" "$CERTBOT_VALIDATION" | curl -s --max-time 20 -K -)
echo "DuckDNS: $(printf '%s\n' "$r" | head -1)"
[ "$(printf '%s\n' "$r" | head -1)" = OK ] || exit 1

# Esperar a ver el TXT (máx ~120 s): primero en el DNS de DuckDNS (dig al puerto 53) y, si la red
# bloquea el DNS directo (pasó con el hotspot del celular el 10/11), por DNS sobre HTTPS de Google.
# Let's Encrypt valida desde sus propios servidores; esto solo evita pedirle la validación antes de tiempo.
visible() {
  { dig +short +time=2 +tries=1 TXT "_acme-challenge.$CERTBOT_DOMAIN" @ns1.duckdns.org 2>/dev/null | tr -d '"'
    curl -s --max-time 5 "https://dns.google/resolve?name=_acme-challenge.$CERTBOT_DOMAIN&type=TXT"
  } | grep -qF "$CERTBOT_VALIDATION"
}
SECONDS=0
until visible; do
  [ "$SECONDS" -ge 120 ] && { echo "TXT aún no visible tras ${SECONDS} s; sigo igual"; break; }
  sleep 5
done
[ "$SECONDS" -lt 120 ] && echo "TXT visible tras ${SECONDS} s"
sleep "${DUCKDNS_EXTRA_WAIT:-30}"
