#!/usr/bin/env bash
# Revisa que el Mac (host) esté listo para el lab. No modifica nada.
# Uso: ./scripts/host-check.sh [--sha]   (--sha verifica el hash de la ISO, tarda ~10 s)
cd "$(dirname "$0")/.." || exit 1
[ -f .env ] && . ./.env

ok()   { printf "  [OK]     %s\n" "$1"; }
bad()  { printf "  [FALTA]  %s\n" "$1"; MISSING=1; }
warn() { printf "  [AVISO]  %s\n" "$1"; }
MISSING=0

arch=$(uname -m)
case "$arch" in
  arm64)  ISO_NAME="ubuntu-26.04-live-server-arm64.iso"
          ISO_SHA="c9aa567e6560b2eddae3af03fc686002e35b6fee96f97fd5df3271e846439fdd" ;;
  x86_64) ISO_NAME="ubuntu-26.04-live-server-amd64.iso"
          ISO_SHA="dec49008a71f6098d0bcfc822021f4d042d5f2db279e4d75bdd981304f1ca5d9" ;;
  *)      ISO_NAME="?"; ISO_SHA="" ;;
esac
ISO="${ISO_PATH:-$HOME/Downloads/$ISO_NAME}"

echo "== Equipo"
ok "Arquitectura: $arch (necesita la ISO $ISO_NAME)"
ram_gb=$(( $(sysctl -n hw.memsize) / 1073741824 ))
[ "$ram_gb" -ge 8 ] && ok "RAM: ${ram_gb} GB" || bad "RAM: ${ram_gb} GB (mínimo 8)"
free_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')
[ "$free_gb" -ge 50 ] && ok "Disco libre: ${free_gb} GB" || bad "Disco libre: ${free_gb} GB (mínimo 50)"

echo "== ISO de Ubuntu"
if [ -f "$ISO" ]; then
  ok "Encontrada: $ISO"
  if [ "${1:-}" = "--sha" ]; then
    got=$(shasum -a 256 "$ISO" | awk '{print $1}')
    [ "$got" = "$ISO_SHA" ] && ok "SHA-256 coincide con el oficial de Canonical" || bad "SHA-256 NO coincide (descarga corrupta o versión distinta)"
  else
    warn "Hash sin verificar (usar --sha)"
  fi
else
  bad "No está $ISO (https://ubuntu.com/download/server)"
fi

echo "== VirtualBox"
VBM=$(command -v VBoxManage || true)
[ -z "$VBM" ] && [ -x /Applications/VirtualBox.app/Contents/MacOS/VBoxManage ] && VBM=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage
if [ -n "$VBM" ]; then
  ok "VirtualBox $("$VBM" --version)"
  nets=$("$VBM" list hostonlynets 2>/dev/null; "$VBM" list hostonlyifs 2>/dev/null)
  if echo "$nets" | grep -q "192.168.56"; then ok "Red host-only 192.168.56.x creada"; else warn "No veo una red host-only 192.168.56.x (créenla en el Administrador de red)"; fi
  vms=$("$VBM" list vms 2>/dev/null)
  echo "$vms" | grep -q '"web01"' && ok "VM web01 creada" || warn "VM web01 aún no existe"
  echo "$vms" | grep -q '"db01"'  && ok "VM db01 creada"  || warn "VM db01 aún no existe"
else
  bad "VirtualBox no instalado (brew install --cask virtualbox)"
fi

echo "== Herramientas del host"
for t in ssh nc dig; do command -v "$t" >/dev/null && ok "$t" || bad "$t"; done
command -v /Applications/FileZilla.app >/dev/null 2>&1 || [ -d /Applications/FileZilla.app ] && ok "FileZilla" || warn "FileZilla no instalado"

echo "== Resolución local y alcance"
if [ -n "${DOMINIO:-}" ]; then
  if grep -qE "^[[:space:]]*[0-9.]+[[:space:]]+.*\b${DOMINIO}\b" /etc/hosts; then ok "/etc/hosts tiene $DOMINIO"; else warn "/etc/hosts no tiene $DOMINIO todavía"; fi
else
  warn "Sin .env: no se revisa el dominio (cp .env.example .env)"
fi
for ip in "${WEB_IP:-192.168.56.11}" "${DB_IP:-192.168.56.12}"; do
  ping -c1 -t2 "$ip" >/dev/null 2>&1 && ok "ping $ip" || warn "ping $ip sin respuesta (VM apagada o sin configurar)"
done

echo
[ "$MISSING" -eq 0 ] && echo "Todo lo imprescindible está listo." || echo "Hay elementos FALTA por resolver."
