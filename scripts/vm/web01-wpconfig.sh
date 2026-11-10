#!/usr/bin/env bash
# Se corre DENTRO de web01 (por SSH). Guía 10.5: crea /var/www/wordpress/wp-config.php.
#   1. Copia wp-config-sample.php con DB_NAME, DB_USER, DB_PASSWORD, DB_HOST (IP:puerto de db01),
#      claves/salts aleatorias y FORCE_SSL_ADMIN. La contraseña se pide en pantalla (no queda en
#      el historial ni en `ps`) y se escapa para PHP, así que sirve aunque tenga ' o \.
#   2. Lo deja wpadmin:www-data 640. Ojo: si se copia "a mano" con `sudo -u wpadmin cp`, el archivo
#      queda con grupo wpadmin y Apache (www-data) NO puede leerlo; por eso el chown.
#   3. Comprueba que Apache (www-data) lo lee y que PHP se conecta a db01 con esos datos.
# Las salts se generan en la VM (módulo `secrets` de Python, aleatorio criptográfico) en vez de
# pegarlas desde api.wordpress.org: mismo resultado, sin copiar y pegar.
# Probado el 10/11: la generación en el Mac (wp-config-sample.php oficial, contraseñas con ' \ $ "
# espacios y acentos) y el script completo en web01 (OK: www-data entra a wordpress_db en db01).
# Uso: bash web01-wpconfig.sh
set -euo pipefail

WP=/var/www/wordpress
CFG=$WP/wp-config.php
DB_NAME=wordpress_db
DB_USER=wp_user
DB_HOST=192.168.56.12:33306

sudo test -f "$WP/wp-config-sample.php" || { echo "No existe $WP/wp-config-sample.php: ¿corriste web01-install.sh?"; exit 1; }
if sudo test -e "$CFG"; then
  echo "Ya existe $CFG. Para rehacerlo: sudo rm $CFG y vuelve a correr este script."; exit 1
fi

while true; do
  read -rsp "Contraseña de $DB_USER (la que pusiste en db01): " P1; echo
  read -rsp "Repítela: " P2; echo
  [ -n "$P1" ] && [ "$P1" = "$P2" ] && break
  echo "Vacía o no coinciden, otra vez."
done

GEN=$(cat <<'PY'
import os, re, secrets, string, sys
sample, cfg, name, user, host = sys.argv[1:6]
pw = sys.stdin.read()
s = open(sample, encoding="utf-8").read()

def php(v):  # literal PHP entre comillas simples: solo \ y ' llevan escape
    return "'" + v.replace("\\", "\\\\").replace("'", "\\'") + "'"

for key, val in (("DB_NAME", name), ("DB_USER", user), ("DB_PASSWORD", pw), ("DB_HOST", host)):
    s, n = re.subn(r"define\(\s*'%s',\s*'[^']*'\s*\);" % key,
                   lambda m, k=key, v=val: "define( '%s', %s );" % (k, php(v)), s)
    if n != 1:
        sys.exit("No encontré exactamente un define de %s en %s" % (key, sample))

chars = string.ascii_letters + string.digits + "!@#$%^&*()-_[]{}<>~+=,.;:/?|"
s, nkeys = re.subn(r"'put your unique phrase here'",
               lambda m: php("".join(secrets.choice(chars) for _ in range(64))), s)
if nkeys < 8:
    sys.exit("Esperaba al menos 8 claves 'put your unique phrase here' y hay %d" % nkeys)

s, n = re.subn(r"^(/\* That's all, stop editing!)",
               lambda m: "/* Lab 5: el panel de administración solo por HTTPS. */\n"
                         "define( 'FORCE_SSL_ADMIN', true );\n\n" + m.group(1), s, flags=re.M)
if n != 1:
    sys.exit("No encontré la línea \"That's all, stop editing!\"")

fd = os.open(cfg, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)  # nunca pisa uno existente
with os.fdopen(fd, "w", encoding="utf-8") as f:
    f.write(s)
print("Escrito %s (%d claves aleatorias)" % (cfg, nkeys))
PY
)

echo "== Generando $CFG"
printf '%s' "$P1" | sudo python3 -I -c "$GEN" "$WP/wp-config-sample.php" "$CFG" "$DB_NAME" "$DB_USER" "$DB_HOST"
unset P1 P2
sudo chown wpadmin:www-data "$CFG"
sudo chmod 640 "$CFG"

echo
echo "== Para el informe (sin contraseña)"
sudo ls -l "$CFG"
sudo grep -E "'(DB_NAME|DB_USER|DB_HOST|FORCE_SSL_ADMIN)'" "$CFG"

echo
echo "== Apache (www-data) lee wp-config.php y PHP se conecta a db01"
sudo -u www-data php -l "$CFG"
# wp-config.php termina con require ABSPATH . 'wp-settings.php': le damos un ABSPATH con un
# wp-settings.php vacío para leer las constantes sin arrancar WordPress.
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
chmod 755 "$T"; : > "$T/wp-settings.php"; chmod 644 "$T/wp-settings.php"
if sudo -u www-data php -- "$T/" "$CFG" <<'PHP'
<?php
define('ABSPATH', $argv[1]);
require $argv[2];
[$h, $port] = array_pad(explode(':', DB_HOST, 2), 2, '3306');
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $c = new mysqli($h, DB_USER, DB_PASSWORD, DB_NAME, (int) $port);
    $u = $c->query('SELECT CURRENT_USER()')->fetch_row()[0];
    echo "OK: PHP (como www-data) entra a ", DB_NAME, " en $h:$port como $u\n";
} catch (mysqli_sql_exception $e) {
    echo "FALLA: ", $e->getMessage(), "\n";
    exit(1);
}
PHP
then
  echo "Listo. Siguiente: certificado y vhost de Apache (guía 11)."
else
  echo "Revisa: contraseña distinta a la de db01, DB_HOST, o UFW/MySQL en db01. Rehacer: sudo rm $CFG"
  exit 1
fi
