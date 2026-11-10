#!/usr/bin/env python3
"""Genera el PDF del informe con LaTeX: pandoc convierte informe/INFORME.md y XeLaTeX lo compone.

Usa la plantilla LaTeX de pandoc más:
  informe/latex/estilo.tex   preámbulo (encabezados, figuras, tablas, código)
  informe/latex/codigo-partible.lua  permite partir rutas largas en código en línea
  una portada generada aquí a partir de los metadatos del Markdown (título, autores, fecha).
Requisitos en el Mac: pandoc, una distribución de LaTeX con xelatex (aquí TinyTeX), rsvg-convert
(diagrama SVG -> PDF) y PyYAML.
Uso: python3 informe/build-pdf.py
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

AQUI = pathlib.Path(__file__).resolve().parent
MD = AQUI / "INFORME.md"
ESTILO = AQUI / "latex" / "estilo.tex"
SALIDA = AQUI / "Informe-Lab5-WordPress-2-capas.pdf"


def tex(texto: str) -> str:
    """Escapa caracteres especiales de LaTeX en textos de la portada."""
    for a, b in (("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"), ("$", r"\$"),
                 ("#", r"\#"), ("_", r"\_"), ("{", r"\{"), ("}", r"\}")):
        texto = texto.replace(a, b)
    return texto


def metadatos() -> dict:
    m = re.match(r"---\n(.*?)\n---\n", MD.read_text(encoding="utf-8"), re.S)
    if not m:
        sys.exit("INFORME.md debe empezar con el bloque YAML de la portada")
    return yaml.safe_load(m.group(1))


def portada(meta: dict) -> str:
    autores = r" \\[2pt] ".join(tex(a) for a in meta["autores"])
    return rf"""
\hypersetup{{pdftitle={{{tex(meta['titulo'])}: {tex(meta['subtitulo'])}}},
            pdfauthor={{{tex(', '.join(meta['autores']))}}},
            pdfsubject={{{tex(meta['curso'])}, {tex(meta['universidad'])}}}}}
\begin{{titlepage}}
  \centering
  {{\large\scshape {tex(meta['universidad'])}\par}}
  \vspace{{2pt}}
  {{\scshape {tex(meta['curso'])}\par}}
  \vspace*{{\fill}}
  \rule{{\linewidth}}{{1pt}}\par
  \vspace{{14pt}}
  {{\LARGE\bfseries {tex(meta['titulo'])}\par}}
  \vspace{{10pt}}
  {{\Large {tex(meta['subtitulo'])}\par}}
  \vspace{{12pt}}
  \rule{{\linewidth}}{{0.4pt}}\par
  \vspace{{2.4cm}}
  {{\normalsize\scshape Autores\par}}
  \vspace{{8pt}}
  {{\large {autores}\par}}
  \vspace*{{\fill}}
  {{\large {tex(meta['fecha'])}\par}}
\end{{titlepage}}
"""


def main():
    for prog in ("pandoc", "xelatex", "rsvg-convert"):
        if not shutil.which(prog):
            sys.exit(f"Falta {prog} en el PATH")
    meta = metadatos()
    diagrama = AQUI / "img" / "diagrama.svg"
    subprocess.run(["rsvg-convert", "-f", "pdf", "-o", str(diagrama.with_suffix(".pdf")), str(diagrama)], check=True)
    with tempfile.TemporaryDirectory() as t:
        tmp = pathlib.Path(t)
        (tmp / "portada.tex").write_text(portada(meta), encoding="utf-8")
        cmd = ["pandoc", str(MD), "-o", str(SALIDA), "--pdf-engine=xelatex",
               "--number-sections", "--toc", "--toc-depth=2", "--syntax-highlighting=monochrome",
               "-H", str(ESTILO), "-B", str(tmp / "portada.tex"),
               "--lua-filter", str(AQUI / "latex" / "codigo-partible.lua"),
               "-V", "documentclass=article", "-V", "fontsize=11pt", "-V", "papersize=letter",
               "-V", "geometry:margin=2.5cm", "-V", "geometry:headheight=14pt", "-V", "indent",
               "-V", "colorlinks", "-V", "linkcolor=black", "-V", "toccolor=black",
               "-V", "urlcolor=blue!45!black", "--resource-path", str(AQUI)]
        r = subprocess.run(cmd, cwd=AQUI, capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("pandoc/xelatex falló:\n" + r.stderr[-4000:])
        avisos = [l for l in r.stderr.splitlines() if "Missing character" in l or "Overfull" in l]
    print(f"PDF: {SALIDA}")
    for a in avisos[:20]:
        print("aviso:", a)


if __name__ == "__main__":
    main()
