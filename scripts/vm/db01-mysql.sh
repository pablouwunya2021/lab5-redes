#!/usr/bin/env bash
# Se corre DENTRO de db01 (por SSH). Capa de datos del lab (guía PDF, sección 9):
#   1. Instala MySQL (Ubuntu 26.04: mysql-server 8.4.11, verificado en packages.ubuntu.com el 10/11).
#   2. Lo deja escuchando SOLO en 192.168.56.12:33306 y apaga el protocolo X (33060).
#      En vez de editar mysqld.cnf, agrega /etc/mysql/mysql.conf.d/zz-lab5.cnf: se lee después
#      (orden alfabético) y gana; para deshacerlo basta borrar ese archivo.
#   3. Crea wordpress_db y wp_user@192.168.56.11 con permisos SOLO sobre esa base (no es admin del motor).
#      La contraseña se pide en pantalla: no queda en el script, ni en el historial, ni en `ps`.
# Probado el 10/11 en db01 (Ubuntu 26.04 arm64): MySQL quedó solo en 192.168.56.12:33306 y los grants correctos.
# Uso: bash db01-mysql.sh
set -euo pipefail

DB_IP=192.168.56.12
WEB_IP=192.168.56.11
PORT=33306
DB=wordpress_db
USR=wp_user
CNF=/etc/mysql/mysql.conf.d/zz-lab5.cnf

sudo apt update
sudo apt install -y mysql-server
sudo test -d /etc/mysql/mysql.conf.d || { echo "No existe /etc/mysql/mysql.conf.d: revisar a mano."; exit 1; }

echo "== Configuración de red de MySQL ($CNF)"
sudo tee "$CNF" >/dev/null <<EOF
# Lab 5: MySQL solo en la red privada, puerto no estándar, sin protocolo X
[mysqld]
bind-address = $DB_IP
port         = $PORT
mysqlx       = OFF
EOF
sudo systemctl restart mysql
sleep 2
echo "Escuchando (debe verse SOLO $DB_IP:$PORT, nada en 3306 ni 33060):"
sudo ss -tlnp | grep -E 'mysqld|:3306 |:33060 ' || echo "  (mysqld no aparece: revisar 'sudo journalctl -u mysql -n 30')"

echo
echo "== Base y usuario de WordPress"
while true; do
  read -rsp "Contraseña nueva para $USR (no se muestra): " P1; echo
  read -rsp "Repítela: " P2; echo
  [ -n "$P1" ] && [ "$P1" = "$P2" ] && break
  echo "Vacía o no coinciden, otra vez."
done
P_SQL=${P1//\\/\\\\}          # escapar \ (MySQL los interpreta dentro de '...')
P_SQL=${P_SQL//\'/\'\'}       # escapar comillas simples
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS $DB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$USR'@'$WEB_IP' IDENTIFIED BY '$P_SQL';
ALTER USER '$USR'@'$WEB_IP' IDENTIFIED BY '$P_SQL';
GRANT ALL PRIVILEGES ON $DB.* TO '$USR'@'$WEB_IP';
FLUSH PRIVILEGES;
SQL
unset P1 P2 P_SQL

echo
echo "== Para el informe (capturas 07 y 08)"
mysql --version
sudo ss -tlnp | grep mysqld
sudo mysql -e "SHOW GRANTS FOR '$USR'@'$WEB_IP';"
sudo mysql -e "SELECT user, host FROM mysql.user WHERE user='$USR';"
echo
echo "Listo. Guarda la contraseña de $USR en tu gestor: la pide wp-config.php en web01."
