#!/usr/bin/env bash
# Se corre DENTRO de cada VM (por SSH). Guía 15: SSH en un puerto no estándar + firewall UFW.
# Dos fases, en el orden de la guía, para no quedarse fuera:
#   abrir   SSH escucha en 22 Y en el puerto nuevo (2222 web01 / 2223 db01). UFW todavía apagado.
#           Luego, SIN cerrar esa sesión, se prueba desde el Mac en una terminal NUEVA: ssh -p <nuevo> ...
#   cerrar  Se corre desde la sesión que entró por el puerto nuevo (el script lo comprueba).
#           Activa UFW (entrada denegada salvo lo necesario) y deja SSH solo en el puerto nuevo.
#           Las sesiones ya abiertas no se cortan (UFW acepta las conexiones establecidas).
# El puerto va en /etc/ssh/sshd_config.d/10-puerto.conf. En Ubuntu 26.04 SSH arranca por ssh.socket:
# `daemon-reload` regenera el socket con los Port de sshd_config. Si aun así no escucha en el puerto
# nuevo, se usa el override de ssh.socket que propone la guía.
# Si algo falla: la sesión abierta sigue viva, y existe el snapshot `servicios-ok` (10/11).
# Probado en el Mac con comandos simulados y en web01 y db01 el 10/11 (ssh.socket tomó el puerto sin
# override; desde el Mac: 22 cerrado en ambas, MySQL cerrado para el host, WordPress sigue en 200).
# Uso: bash ssh-ufw.sh web01|db01 abrir|cerrar
set -euo pipefail

VM=${1:-}; FASE=${2:-}
RED=192.168.56.0/24
WEB_IP=192.168.56.11
case $VM in
  web01) PORT=2222; IP=$WEB_IP ;;
  db01)  PORT=2223; IP=192.168.56.12 ;;
  *) echo "Uso: bash $0 web01|db01 abrir|cerrar"; exit 1 ;;
esac
case $FASE in abrir|cerrar) ;; *) echo "Uso: bash $0 $VM abrir|cerrar"; exit 1 ;; esac
[ "$(hostname)" = "$VM" ] || { echo "Esta VM es $(hostname), no $VM: no hago nada."; exit 1; }

CONF=/etc/ssh/sshd_config.d/10-puerto.conf
OVR_DIR=/etc/systemd/system/ssh.socket.d
OVR=$OVR_DIR/10-lab5-puerto.conf

escucha() { sudo ss -tlnH "sport = :$1" | grep -q .; }

recargar_ssh() {
  sudo systemctl daemon-reload
  if systemctl is-active --quiet ssh.socket; then sudo systemctl restart ssh.socket
  else sudo systemctl restart ssh; fi
  sleep 1
}

# $@ = puertos en los que debe escuchar SSH
poner_puertos() {
  { echo "# Lab 5 (guía 15.1): puerto SSH no estándar"; for p in "$@"; do echo "Port $p"; done; } \
    | sudo tee "$CONF" >/dev/null
  sudo sshd -t                                   # sin salida = configuración correcta
  if sudo test -f "$OVR" || { recargar_ssh; ! escucha "${@: -1}" && systemctl is-active --quiet ssh.socket; }; then
    echo "   ssh.socket necesita override (guía 15.1): $OVR"
    sudo mkdir -p "$OVR_DIR"
    { echo "[Socket]"; echo "ListenStream="; for p in "$@"; do echo "ListenStream=$p"; done; } \
      | sudo tee "$OVR" >/dev/null
    recargar_ssh
  fi
}

mostrar_puertos() {
  sudo ss -tlnp | grep -E ":(22|2222|2223|80|443|33306)[[:space:]]" || true
}

if [ "$FASE" = abrir ]; then
  echo "== 1. SSH en 22 y $PORT (transición, UFW todavía apagado)"
  poner_puertos 22 "$PORT"
  mostrar_puertos
  escucha "$PORT" || { echo "ERROR: nada escucha en $PORT. Revisa: sudo journalctl -u ssh -u ssh.socket -n 30"; exit 1; }
  echo
  echo "OK. NO cierres esta sesión. En una terminal NUEVA del Mac prueba:"
  echo "    ssh -p $PORT sysadmin@$IP"
  echo "Si entra, desde ESA sesión nueva corre:  bash ssh-ufw.sh $VM cerrar"
  exit 0
fi

# ---- cerrar ----
read -r _ _ _ SPORT _ <<< "${SSH_CONNECTION:-- - - -}"
if [ "$SPORT" != "$PORT" ]; then
  echo "Esta sesión entró por el puerto '$SPORT'. Corre 'cerrar' desde una sesión abierta con ssh -p $PORT."
  echo "(Así queda probado que el puerto nuevo funciona antes de cerrar el 22.)"
  exit 1
fi
escucha "$PORT" || { echo "Nada escucha en $PORT: corre primero 'abrir'."; exit 1; }

echo "== 1. UFW: todo lo entrante denegado salvo lo necesario"
command -v ufw >/dev/null || sudo apt install -y ufw
sudo ufw --force reset >/dev/null              # parte de cero (deja respaldo en /etc/ufw/*.rules.*)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from "$RED" to any port "$PORT" proto tcp comment 'SSH y SFTP, solo red privada'
if [ "$VM" = web01 ]; then
  sudo ufw allow 80/tcp comment 'HTTP, solo redirige a HTTPS'
  sudo ufw allow 443/tcp comment 'HTTPS'
else
  sudo ufw allow from "$WEB_IP" to any port 33306 proto tcp comment 'MySQL, solo desde web01'
fi
sudo ufw --force enable                        # sin la pregunta "may disrupt existing ssh connections"

echo
echo "== 2. SSH solo en $PORT"
poner_puertos "$PORT"
if escucha 22; then echo "AVISO: algo sigue escuchando en 22; revisar."; fi

echo
echo "== Para el informe (capturas 18 y $([ "$VM" = web01 ] && echo 19 || echo 20))"
mostrar_puertos
sudo ufw status verbose
echo
echo "Listo. Desde el Mac: ssh -p $PORT sysadmin@$IP  (el 22 ya no responde)."
