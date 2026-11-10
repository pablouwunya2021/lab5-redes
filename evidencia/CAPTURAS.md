# Checklist de capturas

Guardar cada imagen como `NN-descripcion.png` en la carpeta de la persona. Legibles sin zoom, sin tokens ni contraseñas.

| # | Captura | Quién | Rúbrica | Hecha |
|---|---|---|---|---|
| 01 | VirtualBox > Acerca de (versión) | Pablo | Hipervisor | [x] |
| 02 | Red host-only 192.168.56.1/24 | Pablo | Despliegue | [x] |
| 03 | `lsb_release -a` en web01 (26.04 LTS) | Pablo | SO | [x] |
| 04 | `lsb_release -a` en db01 (26.04 LTS) | Pablo | SO | [x] |
| 05 | `ip -br a` en ambas | Pablo | Despliegue | [x] |
| 06 | SSH desde el host a web01 y db01 | Pablo | SSH | [x] |
| 07 | `mysql --version` y `ss -tlnp` (mysqld en 192.168.56.12:33306) | Roberto | 2 capas | [x] |
| 08 | `SHOW GRANTS` de wp_user | Roberto | 2 capas | [x] |
| 09 | `mysql -h ... -P 33306` desde web01 a db01 | Samuel | 2 capas | [x] |
| 10 | Versiones de apache2, php, mysql client | Samuel | Informe | [x] |
| 11 | Pruebas de permisos (www-data y sysadmin denegado, wpadmin ok) y `ls -l` | Samuel | Permisos | [x] |
| 12 | `certbot certificates` | Samuel | HTTPS | [x] |
| 13 | Navegador https://dominio con candado y detalle del certificado | Samuel | HTTPS | [x] |
| 14 | Archivo hosts y `ping dominio` | Pablo | Resolución local | [x] |
| 15 | FileZilla conectado por SFTP a /var/www/wordpress | Pablo | SFTP | [x] |
| 16 | FileZilla: subida con wpadmin OK y error con otro usuario | Pablo | SFTP / Permisos | [x] |
| 17 | Tablas `wp_*` en wordpress_db (SHOW TABLES por SSH en db01) | Roberto | 2 capas / SSH | [x] |
| 18 | `ss -tlnp` con sshd en puerto nuevo, en ambas | Samuel y Roberto | Puertos | [x] |
| 19 | `ufw status verbose` en web01 | Samuel | Firewall | [x] |
| 20 | `ufw status verbose` en db01 | Roberto | Firewall | [x] |
| 21 | Salida de `./scripts/verifica-lab.sh` | Pablo | Pruebas | [x] |
| 22 | Salida de `./scripts/duckdns-dns01.sh` (TXT visible en `_acme-challenge`, sin token en pantalla) | Samuel | HTTPS (justifica DNS-01) | [x] (ver nota) |

Hechas el 10/11: 03-06 en `evidencia/pablo/` (03-05-lsb-release-ip-web01.png, 04-05-lsb-release-ip-db01.png; el prompt `sysadmin@web01` / `sysadmin@db01` en la terminal del Mac sirve de 06). Extra: `instalador-red-*.png`, `apt-full-upgrade-*.png`.

Hechas el 10/11: 10 y 11 en `evidencia/samuel/` (10-versiones.png, 11-permisos.png; 09-mysql-web01-a-db01.png; extra: extra-passwd-wpadmin.png, extra-wp-config.png), 07 y 08 en `evidencia/roberto/07-08-mysql-ss-grants.png` (una sola captura con `mysql --version`, `ss` y `SHOW GRANTS`).

Hechas el 10/11: 12 en `evidencia/samuel/12-certbot-certificates.png` (más `12a-certbot-staging.png` y `12b-certbot-real.png`, recortadas para que no salga el correo de la cuenta), 14 en `evidencia/pablo/14-hosts-ping.png`. Extra: `extra-apache-vhost-configtest.png`, `extra-duckdns-hooks-permisos.png`.

Hechas el 10/11: 17 en `evidencia/roberto/17-show-tables-db01.png`. Para la 13 ya están `evidencia/samuel/13a-wordpress-dashboard-https.png` (panel por HTTPS) y `13b-certificado-openssl.txt` (certificado, cadena hasta ISRG Root X1, TLS 1.3, curl sin -k), y la del navegador: `13c-safari-certificado.png` (cadena ISRG Root X2 > Root YE > YE2, "Este certificado es válido") y `13d-safari-url-https.png`.

Hechas el 10/11: 15 en `evidencia/pablo/15-filezilla-wpadmin-var-www-wordpress.png`. Para la 16 ya están `16a-filezilla-subida-wpadmin.png` y `16b-prueba-sftp-servida-por-https.png` (Apache sirve lo que subió wpadmin) y `16c-filezilla-sysadmin-permission-denied.png` (SSH_FX_PERMISSION_DENIED al listar /var/www/wordpress como sysadmin).

Hechas el 10/11: 19 y la mitad de 18 (web01) en `evidencia/samuel/18-19-ssh2222-ufw-web01.png`. Comprobado desde el Mac: 22 cerrado, 2222/80/443 abiertos.

Hechas el 10/11: 18 (db01) y 20 en `evidencia/roberto/18-20-ssh2223-ufw-db01.png`. Para la 21 ya está la salida en texto `evidencia/pablo/21-verifica-lab.txt` (13 pasan, 0 fallan) y la captura `evidencia/pablo/21-verifica-lab.png`.

La 22 se cubre con `evidencia/samuel/12a-certbot-staging.png` y `12b-certbot-real.png`: muestran el reto DNS-01 real (DuckDNS OK, TXT visible, certificado emitido), que es más fuerte que la prueba previa del 9/11. Repetir `duckdns-dns01.sh` en el hotspot del celular fallaría en las consultas a ns1.duckdns.org y 1.1.1.1 (DNS directo bloqueado, ver informe fila 16).

Para 01 y 02 ya hay respaldo en texto: `evidencia/pablo/01-02-virtualbox-red.txt` (versión, red host-only, NIC de cada VM), y las capturas `evidencia/pablo/01-virtualbox-acerca-de.png` (7.2.22 r175245) y `02-red-host-only.png` (lab5-hostonly, 255.255.255.0, 192.168.56.1 a .10).

Corrección del 10/11: `extra-duckdns-hooks-permisos.png` ahora es el `ls -l` de `/etc/letsencrypt/duckdns/` (antes se había guardado con ese nombre la captura del `scp`, que quedó como `extra-scp-hooks-token-a-web01.png`; no muestra el token).

El PDF usa copias recortadas en `informe/img/` (`python3 informe/preparar-imagenes.py`); estas originales no se modifican.

"Quién" es la fase; si Pablo hace la fase de Samuel, la captura igual va en `evidencia/samuel/`.
