#!/bin/bash
# Hook de certbot (--manual-cleanup-hook): borra el TXT de DuckDNS al terminar la validación.
# Va en web01 como /etc/letsencrypt/duckdns/cleanup.sh (root:root, 700).
# Lee el token de /etc/letsencrypt/duckdns/duckdns.token (root:root, 600).
# DUCKDNS_TOKEN_FILE solo sirve para probarlo fuera de web01. Probado el 10/11 en el Mac.
set -u
TOKEN_FILE=${DUCKDNS_TOKEN_FILE:-/etc/letsencrypt/duckdns/duckdns.token}
TOKEN=$(tr -d '[:space:]' < "$TOKEN_FILE") || exit 1
SUB="${CERTBOT_DOMAIN%.duckdns.org}"
r=$(printf 'url = "https://www.duckdns.org/update?domains=%s&token=%s&txt=removed&clear=true&verbose=true"\n' \
      "$SUB" "$TOKEN" | curl -s --max-time 20 -K -)
echo "DuckDNS: $(printf '%s\n' "$r" | head -1)"
