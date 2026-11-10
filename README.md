# Lab 5: WordPress en 2 capas (Redes Sec. 10, UVG)

Entrega: **10/11/2026** (informe PDF + demo en vivo). Ubuntu Server 26.04 LTS en ambas VM, VirtualBox como hipervisor.

## Equipo y fases

| Fase | Quién | Qué | Guía |
|---|---|---|---|
| 1 | Pablo | VirtualBox, red host-only, VM web01 y db01, SSH desde el host, hosts, FileZilla, diagrama | [docs/pablo-inicio.md](docs/pablo-inicio.md) |
| 2 | Samuel | DuckDNS + Let's Encrypt, Apache/PHP/WordPress, permisos, UFW y SSH de web01 | [docs/samuel-inicio.md](docs/samuel-inicio.md) |
| 3 | Roberto | MySQL en db01, usuario de WordPress, UFW y SSH de db01 | (guía PDF, sección 9 y 15) |
| 4 | Todos | Pruebas, capturas, informe, ensayo | [evidencia/CAPTURAS.md](evidencia/CAPTURAS.md), [informe/INFORME.md](informe/INFORME.md) |

Guía completa con todos los comandos: [docs/Guia-Lab5-WordPress-2-capas.pdf](docs/Guia-Lab5-WordPress-2-capas.pdf). Enunciado: [docs/Laboratorio-Servidor-WordPress-UVG.pdf](docs/Laboratorio-Servidor-WordPress-UVG.pdf).

## Host de la demo

Decisión del 10/11: **Pablo ejecuta las tres fases** en su Mac (Samuel y Roberto repasan cada parte para poder explicarla en la demo).


Las VM de una Mac con chip M (arm64) no corren en el PC de Roberto (x86) y viceversa, así que web01 y db01 viven en **un solo equipo: el Mac de Pablo** (ver [docs/00-variables.md](docs/00-variables.md)). Plan B si VirtualBox arm64 falla: el PC de Roberto.

## Empezar

```bash
git clone <url-del-repo> lab5 && cd lab5     # o usar la carpeta compartida
cp .env.example .env                          # ajustar dominio si ya lo tienen
./scripts/host-check.sh                       # revisa que el Mac esté listo
```

## Estructura

```
docs/        variables del proyecto, guías de arranque, PDFs
config/      plantillas (netplan, Apache, scripts DuckDNS, hosts)
scripts/     host-check.sh y verifica-lab.sh (en el host), vm/ (dentro de las VM)
evidencia/   capturas por persona + CAPTURAS.md (checklist)
informe/     INFORME.md (fuente), img/ (diagrama y capturas recortadas) y el PDF de entrega
```

## Reglas del repo

- **Nunca subir** contraseñas, el token de DuckDNS, claves privadas, ISOs ni discos de VM. `.gitignore` ya los excluye (`.env`, `secrets/`, `*.iso`, `*.vdi`).
- Las plantillas de `config/` usan marcadores `__ASI__`. Se rellenan en la VM, no en el repo.
- El token de DuckDNS vive solo en `secrets/duckdns.token` (Mac) y en `/etc/letsencrypt/duckdns/duckdns.token` (web01, solo root). Los hooks de `config/duckdns/` lo leen de ahí.
- `scripts/vm/web01-install.sh` y `db01-mysql.sh` se probaron en las VM el 10/11. `web01-wpconfig.sh` también (10/11). `ssh-ufw.sh` se probó en web01 y db01 (10/11). Léanlos antes de correrlos.

## Informe PDF

```bash
python3 informe/preparar-imagenes.py    # copias recortadas de las capturas en informe/img/
python3 informe/build-pdf.py            # informe/Informe-Lab5-WordPress-2-capas.pdf (pandoc + Chrome)
```
