# Variables del proyecto

Fuente única de verdad. Si cambia algo, cambien aquí y en `.env`.

| Dato | Valor | Nota |
|---|---|---|
| Host de la demo | **Mac de Pablo** (Apple M5, arm64) | Pablo hace aquí las fases 1 y 2; plan B: PC de Roberto si VirtualBox arm64 falla |
| Red host-only | 192.168.56.0/24 | Host = 192.168.56.1 |
| web01 (VM1) | 192.168.56.11 | Samuel |
| db01 (VM2) | 192.168.56.12 | Roberto |
| Usuario admin de ambas VM | sysadmin | sudo y SSH |
| Usuario SFTP | wpadmin (solo web01) | único con escritura en WordPress |
| Puerto SSH web01 | 2222 | |
| Puerto SSH db01 | 2223 | |
| Puerto MySQL | 33306 | solo desde 192.168.56.11 |
| Base / usuario BD | wordpress_db / wp_user | |
| Dominio | **lab5uvg.duckdns.org** | DuckDNS, creado el 9/11 |
| Carpeta WordPress | /var/www/wordpress | |

## Hardware virtual (creado el 9/11 con `scripts/vbox-crear-vms.sh`)

Red `lab5-hostonly`: 192.168.56.0/24, Mac en 192.168.56.1 (interfaz `bridge100` cuando hay una VM encendida), rango DHCP .1 a .10.

| VM | Adaptador 1 NAT (DHCP 10.0.2.x) | Adaptador 2 host-only (IP fija) |
|---|---|---|
| web01 | 08:00:27:d7:a9:1e | 08:00:27:43:e3:b4 → 192.168.56.11/24 |
| db01 | 08:00:27:b7:3b:2a | 08:00:27:0f:9f:04 → 192.168.56.12/24 |

Las MAC sirven para saber qué interfaz es cuál en la pantalla Network del instalador y en `ip -br link`.

Las contraseñas **no** van aquí. Guárdenlas en un gestor o en un archivo fuera del repo.

## Si el host es el Mac de Pablo

Las VM solo existen en esa Mac. Roberto y Samuel operan en pantalla compartida con Pablo, o repiten los pasos en su propia máquina para practicar y generar capturas de su parte. Acuerden cuál.
