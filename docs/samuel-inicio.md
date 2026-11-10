# Fase 2: Samuel (capa web, certificado y permisos)

Detalle y justificaciones: guía PDF, secciones 10, 12, 13 y 15. Esta hoja es el orden de ejecución.

## A. Lo que puedes hacer YA, sin esperar las VM

### A1. Dominio en DuckDNS (en el navegador)

1. https://www.duckdns.org, iniciar sesión con la cuenta del equipo.
2. Escribir el subdominio y pulsar **add domain**. Creado el 9/11: `lab5uvg`. La IP no hace falta ponerla a mano: el script de A2 la fija en `192.168.56.11`.
3. Copiar el token sin seleccionarlo a mano: en la página de DuckDNS, **Cmd+A y Cmd+C** (copia toda la página). El comando de abajo saca del portapapeles el único UUID que hay (el token) y lo guarda; así nunca se pega en la terminal ni queda en el historial:

```bash
pbpaste | grep -oE '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}' | head -1 > secrets/duckdns.token && chmod 600 secrets/duckdns.token
```

Comprobar con `wc -c < secrets/duckdns.token`: debe dar **37** (36 del token + salto de línea). `secrets/` ya existe (permisos 700) y está en `.gitignore`.

### A2. Probar el reto DNS-01 desde el Mac (el punto más delicado del lab)

Let's Encrypt consulta el TXT de `_acme-challenge.<dominio>`. El script comprueba que DuckDNS lo responde, antes de tocar certbot:

```bash
./scripts/duckdns-dns01.sh lab5uvg
```

Qué hace: (1) fija la IP del subdominio en `192.168.56.11`, (2) publica un TXT de prueba, (3) espera a verlo en `lab5uvg.duckdns.org` y en `_acme-challenge.lab5uvg.duckdns.org` desde `ns1.duckdns.org`, `8.8.8.8` y `1.1.1.1`, (4) lo borra (también con Ctrl-C). Lee el token del archivo y nunca lo imprime. Esperado al final: `Resultado: DNS-01 VIABLE`.

- Si falla `_acme-challenge` en `ns1.duckdns.org`: DuckDNS no sirve, hay que cambiar de proveedor (dominio propio + Cloudflare).
- Si solo fallan `8.8.8.8` / `1.1.1.1`: es caché (TTL), reintentar en un minuto.
- Verificación previa sin token (9/11): DuckDNS responde `_acme-challenge.test.duckdns.org` con los mismos registros que `test.duckdns.org`, así que se espera que pase.

Corrida real del 9/11 con `lab5uvg`: **6/6 PASA** (TXT visible en los 3 servidores al instante, A = 192.168.56.11, TXT borrado al final). **Captura 22.**

### A3. Fijar el dominio

Anota el dominio en `.env` (`DOMINIO=lab5uvg.duckdns.org`), en `docs/00-variables.md` y en `config/hosts-entry.txt`.

## B. Cuando Pablo avise que web01 tiene SSH

```bash
ssh sysadmin@192.168.56.11
```

1. [x] Paquetes, WordPress, usuario `wpadmin` y permisos (script de ayuda, léanlo antes): `scripts/vm/web01-install.sh` o a mano (guía 10.1 a 10.4). Después `sudo passwd wpadmin`. (Hecho el 10/11.)
2. [x] Probar los permisos (guía 10.4): www-data y sysadmin con *Permission denied*, wpadmin con éxito. **Captura 11.** Los `ls` van con `sudo` o como wpadmin: la carpeta es `drwxr-x--- wpadmin www-data` y sysadmin (ni dueño ni del grupo) no puede ni listarla.

   ```bash
   echo "== www-data (debe fallar)"; sudo -u www-data touch /var/www/wordpress/prueba.txt
   echo "== sysadmin (debe fallar)"; touch /var/www/wordpress/prueba.txt
   echo "== wpadmin (debe funcionar)"; sudo -u wpadmin touch /var/www/wordpress/prueba.txt && sudo -u wpadmin ls -l /var/www/wordpress/prueba.txt && sudo -u wpadmin rm /var/www/wordpress/prueba.txt
   echo "== permisos"; ls -ld /var/www/wordpress; sudo ls -l /var/www/wordpress | head
   ```

   El error de sysadmin dice *setting times of* (no *cannot touch*) porque ni siquiera puede entrar a la carpeta: falla al consultar el archivo, antes de intentar crearlo. www-data sí entra (grupo r-x) pero no puede escribir.
3. [x] Cuando Roberto avise que db01 está listo: probar `mysql -h 192.168.56.12 -P 33306 -u wp_user -p wordpress_db`. **Captura 09.**
4. [x] `wp-config.php` (guía 10.5, `DB_HOST` = `192.168.56.12:33306`): `scripts/vm/web01-wpconfig.sh` (pide la contraseña de wp_user y al final prueba la conexión desde PHP como www-data). Si se hace a mano como dice la guía, después del `cp` falta `sudo chown wpadmin:www-data wp-config.php && sudo chmod 640 wp-config.php`: el `cp` de wpadmin deja el grupo `wpadmin` y Apache no podría leerlo.
5. [x] Certificado (guía 12.4 y 12.5). Los hooks `config/duckdns/auth.sh` y `cleanup.sh` **no llevan el token**: lo leen de `/etc/letsencrypt/duckdns/duckdns.token` (solo root). Se copian por SCP desde el Mac (usa `-P 2222` si ya cambiaste el puerto):

   ```bash
   # en el Mac, desde la carpeta del repo
   scp config/duckdns/auth.sh config/duckdns/cleanup.sh secrets/duckdns.token config/apache-wordpress.conf web01:
   ```

   ```bash
   # en web01 (ssh web01)
   sudo install -d -m 700 /etc/letsencrypt/duckdns
   sudo install -m 700 -o root -g root ~/auth.sh ~/cleanup.sh /etc/letsencrypt/duckdns/
   sudo install -m 600 -o root -g root ~/duckdns.token /etc/letsencrypt/duckdns/duckdns.token
   shred -u ~/duckdns.token && rm ~/auth.sh ~/cleanup.sh
   sudo ls -l /etc/letsencrypt/duckdns/

   D=lab5uvg.duckdns.org     # el dominio real
   sudo certbot certonly --manual --preferred-challenges dns \
     --manual-auth-hook /etc/letsencrypt/duckdns/auth.sh \
     --manual-cleanup-hook /etc/letsencrypt/duckdns/cleanup.sh \
     -d "$D" --agree-tos -m CORREO_DEL_EQUIPO --no-eff-email --staging
   # si dice "Successfully received certificate", repetir SIN --staging y CON --force-renewal
   sudo certbot certificates
   ```

   `auth.sh` sale con error si DuckDNS responde `KO` y espera hasta ver el TXT (en `ns1.duckdns.org` o, si la red bloquea el DNS directo, por DNS sobre HTTPS de Google; máx 120 s) más 30 s de margen. Hooks probados el 10/11 en el Mac con el dominio real (TXT visible a los 3 s, limpieza OK, token falso → error). **Captura 12** de `certbot certificates`.
6. [x] Virtual host: `config/apache-wordpress.conf` (reemplazar `__DOMINIO__`), `a2ensite`, `configtest`, reload (guía 13.1).
7. [x] Instalar WordPress desde https://tu-dominio (necesita el hosts de Pablo). **Captura** con candado.
8. [ ] SFTP optativo solo-wpadmin (guía 14.1).

## C. Cierre de seguridad (con snapshot antes)

- [x] Snapshot de web01 y db01: `servicios-ok` (10/11, tomado con las VM apagadas).
- [x] Puerto SSH a 2222 y UFW con `scripts/vm/ssh-ufw.sh` (guía 15.1 a 15.3), en dos fases: `bash ssh-ufw.sh web01 abrir` (SSH en 22 y 2222), probar `ssh -p 2222` en una terminal NUEVA y, desde esa sesión, `bash ssh-ufw.sh web01 cerrar` (UFW + solo 2222). En db01 igual con `db01` (puerto 2223, MySQL solo desde 192.168.56.11).
- [x] UFW de web01: 2222 (red privada), 80, 443 (guía 15.3). **Captura** de `ufw status verbose`.

## D. Si quieres practicar en tu Mac mientras tanto

Repite la hoja de Pablo (VirtualBox, ISO según tu chip: `uname -m`). Sirve para entender cada paso. Las capturas del informe deben venir de la maqueta real de la demo.
