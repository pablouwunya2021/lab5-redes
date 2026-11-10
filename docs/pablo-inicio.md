# Fase 1: Pablo (infraestructura y acceso remoto)

Detalle y justificaciones: guía PDF, secciones 5 a 8, 11 y 14. Esta hoja es el orden de ejecución.

## 0. Estado de tu Mac (ya revisado)

- Chip M5 (arm64), 16 GB de RAM, 198 GB libres: alcanza para dos VM de 2 GB.
- ISO `~/Downloads/ubuntu-26.04-live-server-arm64.iso` ya descargada y su SHA-256 **coincide con el oficial de Canonical** (c9aa567e...). No hay que bajar otra.
- VirtualBox **no está instalado**. (UTM sí, pero el lab pide VirtualBox o VMware Workstation Pro.)

```bash
./scripts/host-check.sh --sha
```

Corrida del 9/11: todo OK salvo VirtualBox (FALTA) y FileZilla (AVISO). El ping a las VM falla porque todavía no existen.

## 1. Instalar VirtualBox y FileZilla

VirtualBox: Homebrew trae la **7.2.22 (r175245) para Arm64** (`VirtualBox-7.2.22-175245-macOSArm64.dmg`, 159 MB, de download.virtualbox.org). Pide tu contraseña:

```bash
brew install --cask virtualbox
```

Opción B: bajar el .dmg "macOS / Arm64 hosts" de https://www.virtualbox.org/wiki/Downloads.

Si macOS bloquea: Ajustes del Sistema > Privacidad y seguridad > Permitir (software de Oracle) y reinicia. Si pide permiso de Red local o Monitorización de entrada para VirtualBox, acéptalo. Luego:

```bash
VBoxManage --version
```

**Captura 01**: VirtualBox > Acerca de.

FileZilla **no está en Homebrew** (el cask ya no existe). Bajarlo de https://filezilla-project.org/download.php?show_all=1 y elegir el archivo `macos-arm64.app.tar.bz2` (no el instalador "sponsored"). Doble clic lo descomprime; mover `FileZilla.app` a Aplicaciones. Alternativa aceptada por el enunciado ("o equivalente"): `brew install --cask cyberduck`, pero la rúbrica nombra FileZilla.

## 2 y 3. Red host-only y VM web01 / db01 (script)

```bash
./scripts/vbox-crear-vms.sh --dry-run     # muestra los comandos sin ejecutar nada
./scripts/vbox-crear-vms.sh               # crea la red y las 2 VM (apagadas, con la ISO montada)
```

Qué crea (valores de `docs/00-variables.md`):

| | Valor | Por qué |
|---|---|---|
| Red `lab5-hostonly` | 192.168.56.0/24, `--lower-ip=192.168.56.1`, `--upper-ip=192.168.56.10` | En macOS la red host-only va sobre vmnet de Apple y **no tiene casilla de DHCP**: el límite inferior es la IP que toma el Mac. Comprobado el 9/11: el Mac quedó en 192.168.56.1 (`bridge100`). .11 y .12 quedan fuera del rango DHCP. |
| web01 y db01 | Tipo "Ubuntu (ARM 64-bit)", 2048 MB, 2 CPU, disco VDI dinámico de 20 GB, EFI, VMSVGA, audio apagado | VirtualBox 7.2.22 no tiene un tipo "Ubuntu 26.04": se usa el genérico ARM. |
| Adaptadores | 1 = NAT, 2 = host-only `lab5-hostonly` | NAT para internet, host-only para SSH/HTTPS/SFTP/MySQL. |

Probado el 9/11 con VM y red desechables (prefijo `zz-`): crea todo, una segunda corrida no duplica nada, y la VM arranca la ISO hasta el instalador de **Ubuntu 26.04 LTS**. Todo lo de prueba se borró.

**Captura 02**: VirtualBox > Archivo > Herramientas > Administrador de red, pestaña Host-only Networks, con `lab5-hostonly`. Opcional para el informe: el bloque "Resumen" que imprime el script.

Si prefieres la interfaz gráfica: New, ISO arm64, **Skip Unattended Installation**, Linux / Ubuntu (ARM 64-bit), 2048 MB, 2 CPU, disco 20 GB; Settings: Adapter 1 NAT, Adapter 2 Host-only `lab5-hostonly`, Display VMSVGA.

## 4. Instalar Ubuntu (instalador)

Arrancar cada VM con ventana (doble clic en VirtualBox, o `VBoxManage startvm web01`). Se pueden instalar las dos a la vez.

- GRUB: **Try or Install Ubuntu Server**.
- Hostname `web01` / `db01`, usuario `sysadmin`, **marcar Install OpenSSH server**, sin snaps.
- Network: NAT en DHCP (10.0.2.x); la host-only en **Manual**: subnet `192.168.56.0/24`, address `192.168.56.11` (web01) o `192.168.56.12` (db01), **gateway y DNS vacíos**.
- Al terminar, "Reboot Now". Si pide quitar el medio, desmontar la ISO (con la VM apagada o desde Devices > Optical Drives > Remove disk):

```bash
VBoxManage storageattach web01 --storagectl=VirtioSCSI --port=1 --device=0 --type=dvddrive --medium=emptydrive
```

## 5. Primer arranque (una sola vez en la consola)

```bash
lsb_release -a                       # CAPTURA: Ubuntu 26.04 LTS
ip -br a
sudo apt update && sudo apt full-upgrade -y
```

Si la IP host-only no quedó: plantillas en `config/netplan-web01.yaml` y `config/netplan-db01.yaml` (ajusta el nombre de interfaz con `ip -br a`).

## 6. SSH desde tu Mac

```bash
ssh sysadmin@192.168.56.11
ssh sysadmin@192.168.56.12
```

Atajo (tu Mac todavía no tiene `~/.ssh/config`): crea uno con los nombres `web01` y `db01`, así sirven `ssh web01` y `scp archivo web01:`.

```bash
cat config/ssh-config.example >> ~/.ssh/config && chmod 600 ~/.ssh/config
```

Desde aquí **no se usa más la consola de VirtualBox**. **Captura 06.**

## 7. Snapshots (con la VM apagada)

En VirtualBox para ARM los snapshots en vivo (`--live`, que guardan la RAM) fallan con `VERR_SSM_TOO_MANY_PASSES`. Tomarlos con la VM apagada: solo guardan el disco y son instantáneos.

```bash
VBoxManage controlvm web01 acpipowerbutton      # apagado ordenado (como pulsar el botón)
# esperar a que VBoxManage showvminfo web01 --machinereadable | grep VMState  diga "poweroff"
VBoxManage snapshot web01 take base-limpia --description="Ubuntu 26.04 recién instalado"
VBoxManage startvm web01 --type=headless        # sin ventana: todo sigue por SSH
```

Tomar uno antes de la sección 15 (puertos SSH y UFW) es obligatorio.

Hecho el 10/11: `base-limpia` en web01 y db01 (Ubuntu actualizado, antes de instalar servicios) y `servicios-ok` (WordPress con HTTPS y MySQL funcionando, antes de puertos SSH y UFW). Para volver a él: apagar la VM y correr `VBoxManage snapshot <vm> restore base-limpia`.

Si el Mac entra en reposo, VirtualBox pausa las VM y no siempre las reanuda. Mientras trabajas, deja el cargador conectado y corre `caffeinate -dims` en otra pestaña de la Terminal (Ctrl+C lo quita).

## 8. Tu parte restante (cuando Samuel tenga el dominio)

- [x] Archivo hosts: línea de `config/hosts-entry.txt` en `/etc/hosts` + `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`
- [x] FileZilla (SFTP, usuario `wpadmin`, puerto vigente de web01), subir y editar un archivo
- [ ] Diagrama con IPs, nombres, puertos y protocolos
- [ ] Ejecutar `./scripts/verifica-lab.sh` al final y guardar la salida como captura
- [ ] Ensamblar el PDF del informe (`informe/INFORME.md`)

## Evidencias que salen de esta fase

Guárdalas en `evidencia/pablo/` con el número de `evidencia/CAPTURAS.md`.
