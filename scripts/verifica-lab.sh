#!/usr/bin/env bash
# Batería de pruebas de red desde el host (Mac). Para el ensayo y la captura final.
# Uso: ./scripts/verifica-lab.sh
cd "$(dirname "$0")/.." || exit 1
[ -f .env ] && . ./.env
WEB_IP=${WEB_IP:-192.168.56.11}; DB_IP=${DB_IP:-192.168.56.12}
WEB_SSH_PORT=${WEB_SSH_PORT:-2222}; DB_SSH_PORT=${DB_SSH_PORT:-2223}; MYSQL_PORT=${MYSQL_PORT:-33306}
PASS=0; FAIL=0

# macOS nc: -G = timeout de conexión (sin él, una IP que no responde cuelga el script)
abierto()  { if nc -z -G 3 -w 3 "$1" "$2" >/dev/null 2>&1; then printf "  [PASA]  %s:%s abierto\n" "$1" "$2"; PASS=$((PASS+1)); else printf "  [FALLA] %s:%s deberia estar ABIERTO\n" "$1" "$2"; FAIL=$((FAIL+1)); fi; }
cerrado()  { if nc -z -G 3 -w 3 "$1" "$2" >/dev/null 2>&1; then printf "  [FALLA] %s:%s deberia estar CERRADO\n" "$1" "$2"; FAIL=$((FAIL+1)); else printf "  [PASA]  %s:%s cerrado\n" "$1" "$2"; PASS=$((PASS+1)); fi; }

echo "== Alcance"
for ip in "$WEB_IP" "$DB_IP"; do ping -c1 -t2 "$ip" >/dev/null 2>&1 && { echo "  [PASA]  ping $ip"; PASS=$((PASS+1)); } || { echo "  [FALLA] ping $ip"; FAIL=$((FAIL+1)); }; done

echo "== web01 ($WEB_IP): lo que SI debe estar abierto"
abierto "$WEB_IP" "$WEB_SSH_PORT"; abierto "$WEB_IP" 443; abierto "$WEB_IP" 80
echo "== web01: lo que debe estar cerrado"
cerrado "$WEB_IP" 22

echo "== db01 ($DB_IP): SSH abierto, MySQL cerrado para el host (solo web01 puede)"
abierto "$DB_IP" "$DB_SSH_PORT"
cerrado "$DB_IP" "$MYSQL_PORT"; cerrado "$DB_IP" 3306; cerrado "$DB_IP" 22

if [ -n "${DOMINIO:-}" ]; then
  echo "== Resolución local de $DOMINIO (archivo hosts)"
  if grep -qE "^[[:space:]]*$WEB_IP[[:space:]]+([^#]*[[:space:]])?$DOMINIO([[:space:]]|$)" /etc/hosts \
     && dscacheutil -q host -a name "$DOMINIO" | grep -qx "ip_address: $WEB_IP"; then
    echo "  [PASA]  /etc/hosts: $DOMINIO -> $WEB_IP"; PASS=$((PASS+1))
  else echo "  [FALLA] $DOMINIO no resuelve a $WEB_IP por /etc/hosts"; FAIL=$((FAIL+1)); fi

  echo "== HTTP y HTTPS por nombre"
  r=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 10 "http://$DOMINIO/")
  if [ "$r" = "301 https://$DOMINIO/" ]; then echo "  [PASA]  http:// redirige (301) a https://"; PASS=$((PASS+1))
  else echo "  [FALLA] http:// respondió '$r' (se esperaba 301 a https://$DOMINIO/)"; FAIL=$((FAIL+1)); fi
  r=$(curl -s -o /dev/null -w '%{http_code} %{ssl_verify_result}' --max-time 10 "https://$DOMINIO/")
  if [ "$r" = "200 0" ]; then echo "  [PASA]  https:// responde 200 con certificado válido (Let's Encrypt)"; PASS=$((PASS+1))
  else echo "  [FALLA] https:// respondió '$r' (se esperaba '200 0': código HTTP y verificación TLS)"; FAIL=$((FAIL+1)); fi
fi

echo; echo "Resultado: $PASS pasan, $FAIL fallan"
[ "$FAIL" -eq 0 ]
