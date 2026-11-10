#!/usr/bin/env python3
"""Copias recortadas de las capturas para el PDF (informe/img/). Las originales de evidencia/ no se tocan.

Las capturas de terminal tienen mucho espacio vacío a la derecha y abajo: al recortarlo, la letra se ve
más grande en el PDF. Algunas además llevan un recorte fijo arriba (mensaje de bienvenida de Ubuntu) o
abajo (página casi en blanco).
Uso: python3 informe/preparar-imagenes.py
"""
import pathlib
from collections import Counter

from PIL import Image, ImageChops

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DEST = RAIZ / "informe" / "img"

# origen -> (recorte fijo arriba, abajo o None, derecha o None, ¿recortar el vacío de la derecha y de abajo?)
CAPTURAS = {
    "evidencia/pablo/03-05-lsb-release-ip-web01.png": (0, None, None, True),
    "evidencia/pablo/04-05-lsb-release-ip-db01.png": (0, None, None, True),
    "evidencia/pablo/apt-full-upgrade-web01.png": (0, None, None, True),
    "evidencia/roberto/07-08-mysql-ss-grants.png": (388, None, None, True),
    "evidencia/samuel/09-mysql-web01-a-db01.png": (0, None, None, True),
    "evidencia/samuel/10-versiones.png": (0, None, None, True),
    "evidencia/samuel/11-permisos.png": (0, None, None, True),
    "evidencia/samuel/12-certbot-certificates.png": (0, None, None, True),
    "evidencia/samuel/12b-certbot-real.png": (0, None, None, True),
    "evidencia/samuel/13a-wordpress-dashboard-https.png": (0, 900, None, False),
    "evidencia/pablo/14-hosts-ping.png": (0, None, None, True),
    "evidencia/pablo/16b-prueba-sftp-servida-por-https.png": (0, 260, None, False),
    "evidencia/roberto/17-show-tables-db01.png": (720, 1272, 960, False),
    "evidencia/samuel/18-19-ssh2222-ufw-web01.png": (0, None, None, True),
    "evidencia/roberto/18-20-ssh2223-ufw-db01.png": (270, None, 1620, False),
    "evidencia/pablo/21-verifica-lab.png": (0, None, 1250, False),
    "evidencia/samuel/extra-apache-vhost-configtest.png": (0, None, None, True),
    "evidencia/samuel/extra-duckdns-hooks-permisos.png": (0, None, None, True),
    "evidencia/samuel/extra-wp-config.png": (0, None, None, True),
}
MARGEN = 28      # píxeles que se dejan alrededor del contenido
UMBRAL = 45      # diferencia de color con el fondo para considerar que un píxel es texto


HUECO = 150      # un vacío de al menos esto separa el texto de adornos sueltos (íconos, barras de desplazamiento)
ADORNO = 0.07    # bloques al final más angostos que esta fracción de la imagen se descartan


def fondo(im: Image.Image):
    """Color más frecuente de la imagen (el fondo de la terminal)."""
    return Counter(im.resize((200, 100)).get_flattened_data()).most_common(1)[0][0]


def fin_del_contenido(ocupado, total):
    """Último índice con contenido, ignorando bloques pequeños separados por un hueco grande al final."""
    bloques, inicio, ultimo = [], None, None
    for i, o in enumerate(ocupado):
        if o:
            if inicio is None:
                inicio = i
            elif i - ultimo > HUECO:
                bloques.append((inicio, ultimo)); inicio = i
            ultimo = i
    if inicio is None:
        return total - 1
    bloques.append((inicio, ultimo))
    while len(bloques) > 1 and (bloques[-1][1] - bloques[-1][0]) < ADORNO * total:
        bloques.pop()
    return bloques[-1][1]


def sin_vacio(im: Image.Image) -> Image.Image:
    w, h = im.size
    plano = Image.new("RGB", im.size, fondo(im))
    dif = ImageChops.difference(im, plano).convert("L").point(lambda v: 255 if v > UMBRAL else 0)
    datos = dif.tobytes()
    columnas = [any(datos[y * w + x] for y in range(0, h, 2)) for x in range(w)]
    filas = [any(datos[y * w:(y + 1) * w]) for y in range(h)]
    derecha = fin_del_contenido(columnas, w)
    abajo = fin_del_contenido(filas, h)
    return im.crop((0, 0, min(w, derecha + MARGEN), min(h, abajo + MARGEN)))


def main():
    DEST.mkdir(exist_ok=True)
    for origen, (arriba, abajo, derecha, vacio) in CAPTURAS.items():
        im = Image.open(RAIZ / origen).convert("RGB")
        w, h = im.size
        im = im.crop((0, arriba, derecha or w, abajo or h))
        if vacio:
            im = sin_vacio(im)
        destino = DEST / pathlib.Path(origen).name
        im.save(destino)
        print(f"{destino.relative_to(RAIZ)}: {w}x{h} -> {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
