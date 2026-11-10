#!/usr/bin/env bash
# Se corre DENTRO de web01 (por SSH). Instala paquetes, descarga WordPress y deja permisos.
# Probado el 10/11 en web01 (Ubuntu 26.04 arm64): Apache 2.4.66, PHP 8.5.4, cliente MySQL 8.4.11, permisos 750/640 OK.
# Nombres de paquetes verificados para Ubuntu 26.04 arm64 en packages.ubuntu.com (10/11):
# apache2 2.4.66, PHP 8.5, mysql-client 8.4.11, certbot 4.0; dnsutils es virtual -> bind9-dnsutils.
# adduser 3.153 usa --comment (--gecos es la opcion antigua).
# Uso: bash web01-install.sh
set -euo pipefail

WP_DIR=/var/www/wordpress
WP_ADMIN=wpadmin

sudo apt update
sudo apt install -y apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring \
  php-xml php-zip php-intl mysql-client certbot bind9-dnsutils curl
sudo a2enmod ssl rewrite headers

# Usuario con escritura en WordPress (sin contraseña hasta que se asigne a mano)
id "$WP_ADMIN" >/dev/null 2>&1 || sudo adduser --disabled-password --comment "Administrador SFTP de WordPress" "$WP_ADMIN"

# WordPress (solo si todavía no está)
if [ ! -f "$WP_DIR/wp-load.php" ]; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/latest.tar.gz" https://wordpress.org/latest.tar.gz
  tar -xzf "$tmp/latest.tar.gz" -C "$tmp"
  sudo mkdir -p "$WP_DIR"
  sudo cp -a "$tmp/wordpress/." "$WP_DIR/"
  rm -rf "$tmp"
fi

# Permisos: solo wpadmin escribe; Apache (www-data) lee; otros nada
sudo chown -R "$WP_ADMIN":www-data "$WP_DIR"
sudo find "$WP_DIR" -type d -exec chmod 750 {} \;
sudo find "$WP_DIR" -type f -exec chmod 640 {} \;

echo
echo "Versiones (para el informe):"
apache2 -v | head -1; php -v | head -1; mysql --version
echo
echo "Pendiente a mano:"
echo "  1) sudo passwd $WP_ADMIN                (contraseña para SFTP)"
echo "  2) probar permisos (guia 10.4) y crear wp-config.php (guia 10.5)"
