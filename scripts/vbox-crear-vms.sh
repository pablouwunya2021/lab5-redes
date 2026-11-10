#!/usr/bin/env bash
# Crea en VirtualBox (Mac con chip M) la red host-only y las VM web01 y db01 del lab, APAGADAS y con la
# ISO de Ubuntu 26.04 arm64 montada. Valores de docs/00-variables.md. No arranca nada ni toca lo que ya existe.
#
# Sintaxis tomada de la ayuda de VBoxManage 7.2.22 y comprobada el 9/11 con una VM y una red desechables:
#   - En macOS la red host-only va sobre vmnet de Apple: --lower-ip es la IP que toma el Mac
#     (con 192.168.56.1 el Mac quedó en 192.168.56.1, interfaz bridge100). El resto del rango
#     (hasta .10) queda para DHCP; web01 (.11) y db01 (.12) usan IP fija fuera de ese rango.
#   - createvm --default para Ubuntu_arm64 deja: EFI, chipset armv8virtual, VMSVGA, controlador VirtioSCSI.
#     No hay tipo "Ubuntu 26.04": se usa el genérico "Ubuntu (ARM 64-bit)".
#
# Uso: ./scripts/vbox-crear-vms.sh             crea lo que falte
#      ./scripts/vbox-crear-vms.sh --dry-run   solo muestra los comandos
# LAB5_PREFIJO=zz- crea zz-web01, zz-db01 y zz-lab5-hostonly (solo para probar el script).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
[ -f .env ] && . ./.env

P=${LAB5_PREFIJO:-}
NET_NOMBRE="${P}lab5-hostonly"
HOST_IP=${HOST_IP:-192.168.56.1}
DHCP_FIN=192.168.56.10
ISO=${ISO_PATH:-$HOME/Downloads/ubuntu-26.04-live-server-arm64.iso}
RAM=2048; CPUS=2; DISCO_MB=20480
VMS=("${P}web01" "${P}db01")

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
run() { printf '+ %s\n' "$*"; [ "$DRY" -eq 1 ] || "$@"; }

# --- Comprobaciones previas
[ "$(uname -m)" = arm64 ] || { echo "Este script es para Mac con chip M (arm64)."; exit 1; }
command -v VBoxManage >/dev/null || { echo "Falta VirtualBox (brew install --cask virtualbox)."; exit 1; }
[ -f "$ISO" ] || { echo "No encuentro la ISO: $ISO (o define ISO_PATH en .env)."; exit 1; }
echo "VirtualBox $(VBoxManage --version) | ISO $(basename "$ISO")"

# --- 1. Red host-only (si ya hay una cuyo Mac sea 192.168.56.1, se reutiliza)
NET=$(VBoxManage list hostonlynets | awk -v ip="$HOST_IP" '
  /^Name:/    { n=$0; sub(/^Name:[ ]+/, "", n) }
  /^LowerIP:/ { if ($2 == ip) { print n; exit } }')
if [ -n "$NET" ]; then
  echo "== Red host-only: ya existe '$NET' con el Mac en $HOST_IP, se reutiliza"
else
  NET=$NET_NOMBRE
  echo "== Red host-only: creando '$NET' ($HOST_IP/24)"
  run VBoxManage hostonlynet add --name="$NET" --netmask=255.255.255.0 \
      --lower-ip="$HOST_IP" --upper-ip="$DHCP_FIN" --enable
fi

# --- 2. Máquinas virtuales
BASE=$(VBoxManage list systemproperties | sed -n 's/^Default machine folder: *//p')
for vm in "${VMS[@]}"; do
  if VBoxManage list vms | grep -q "^\"$vm\" "; then
    echo "== $vm: ya existe, no se toca"; continue
  fi
  echo "== $vm: creando"
  run VBoxManage createvm --name="$vm" --platform-architecture=arm --ostype=Ubuntu_arm64 --default --register
  run VBoxManage modifyvm "$vm" --memory="$RAM" --cpus="$CPUS" --graphicscontroller=vmsvga \
      --audio-enabled=off --nic1=nat --nic2=hostonlynet --host-only-net2="$NET" \
      --description="Lab 5 Redes UVG. Adaptador 1 NAT (internet), adaptador 2 host-only $NET."

  CTL=VirtioSCSI
  if [ "$DRY" -eq 0 ]; then
    CTL=$(VBoxManage showvminfo "$vm" --machinereadable | sed -n 's/^storagecontrollername0="\(.*\)"$/\1/p')
    [ -n "$CTL" ] || { echo "No encontré el controlador de disco de $vm"; exit 1; }
  fi
  DISCO="$BASE/$vm/$vm.vdi"
  run VBoxManage createmedium disk --filename="$DISCO" --size="$DISCO_MB" --format=VDI
  run VBoxManage storageattach "$vm" --storagectl="$CTL" --port=0 --device=0 --type=hdd --medium="$DISCO"
  run VBoxManage storageattach "$vm" --storagectl="$CTL" --port=1 --device=0 --type=dvddrive --medium="$ISO"
done

# --- 3. Resumen (para la captura 02 y el informe)
[ "$DRY" -eq 1 ] && exit 0
echo
echo "== Resumen"
VBoxManage list hostonlynets | grep -A6 "^Name: *$NET$" | grep -E "^(Name|State|NetworkMask|LowerIP|UpperIP):"
for vm in "${VMS[@]}"; do
  echo "-- $vm"
  VBoxManage showvminfo "$vm" --machinereadable | grep -E \
    '^(ostype|platformArchitecture|memory|cpus|firmware|graphicscontroller|nic1|nic2|hostonly-network2|VMState)=|^"[A-Za-z]+-[01]-0"=' \
    | sed 's/^/   /'
done
echo
echo "Siguiente: arrancar cada VM con la ventana de VirtualBox para el instalador (docs/pablo-inicio.md, paso 4)."
