#!/usr/bin/env python3
"""Regenerate latin1-not-utf8.md, the non-UTF8 fixture used by TEST_PLAN.md section A.

Vera reads text files with String(contentsOf:encoding: .utf8). This file is
ISO-8859-1, so it is treated as text (a .md extension), fails to decode, and must
produce "Couldn't Open File" while leaving the bytes on disk untouched.

Run from anywhere:  python3 screenshots-tmp/make-latin1-fixture.py
"""
import hashlib
import pathlib

target = pathlib.Path(__file__).resolve().parent / "latin1-not-utf8.md"

# Kept as plain ASCII here so the source stays readable, then substituted with the
# accented forms below. Each accented character encodes to a single high byte in
# Latin-1 with no UTF-8 continuation byte after it, which is what makes the result
# invalid UTF-8 rather than merely unusual.
text = """# Notas de la reunion (Latin-1)

Fichero de prueba. NO es UTF-8: esta codificado en ISO-8859-1, como los ficheros
de texto que salen de sistemas antiguos.

Vera debe rechazarlo con "Couldn't Open File" y **no debe tocar el fichero**.

## Participantes

- Miguel Baeyens, direccion tecnica
- Jose Maria Anon, integracion
- Begona Nunez, calidad

## Acuerdos

1. El anadido de la cache queda pendiente de revision.
2. La migracion se hara en pequenas fases.
3. Manana se envia el resumen a la direccion.

## Caracteres que rompen la decodificacion

Vocales acentuadas: a e i o u -> aeiou
Enye mayuscula y minuscula: NN nn
Simbolos: (c) (r) 1/2 1/4 " " << >>
Moneda: 100 EUR, 250 GBP

Cafe, jamon, campana, montana, corazon, razon, tambien, quiza.
"""

replacements = {
    "reunion": "reunión",
    "esta codificado": "está codificado",
    "direccion tecnica": "dirección técnica",
    "Jose Maria Anon": "José María Añón",
    "integracion": "integración",
    "Begona Nunez": "Begoña Núñez",
    "El anadido de la cache queda pendiente de revision.":
        "El añadido de la caché queda pendiente de revisión.",
    "La migracion se hara en pequenas fases.":
        "La migración se hará en pequeñas fases.",
    "Manana se envia el resumen a la direccion.":
        "Mañana se envía el resumen a la dirección.",
    "decodificacion": "decodificación",
    "a e i o u -> aeiou": "á é í ó ú à è ì ò ù",
    "NN nn": "Ñ ñ",
    '(c) (r) 1/2 1/4 " " << >>': "© ® ½ ¼ « » ¡ ¿ µ ±",
    "100 EUR, 250 GBP": "100 ¤, 250 £, 90 ¥, 40 ¢",
    "Cafe, jamon, campana, montana, corazon, razon, tambien, quiza.":
        "Café, jamón, campaña, montaña, corazón, razón, también, quizá.",
}
for plain, accented in replacements.items():
    if plain not in text:
        raise SystemExit(f"replacement target missing: {plain!r}")
    text = text.replace(plain, accented)

data = text.encode("latin-1")
target.write_bytes(data)

# The fixture is worthless if it happens to be valid UTF-8, so assert it isn't.
try:
    data.decode("utf-8")
except UnicodeDecodeError as exc:
    print(f"invalid UTF-8 as intended: {exc}")
else:
    raise SystemExit("file decoded as UTF-8 and would not exercise the test")

print(f"path:   {target}")
print(f"bytes:  {len(data)}")
print(f"sha256: {hashlib.sha256(data).hexdigest()}")
