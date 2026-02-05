---
layout: default
title: tito-pdf (Español)
permalink: /docs/es/
---

# tito-pdf (guía rápida)
`tito-pdf` convierte `.pdf` / `.docx` a Markdown (y opcionalmente extrae tablas), de forma local/determinística (sin LLM).

## Recomendado (salida explícita)
Usá `--md-out` para controlar el path del output:

```bash
tito-pdf input.pdf --md-out out/input.md
```

## Convenience mode
Sin paths explícitos, escribe junto al input:

```bash
tito-pdf /path/al/doc.pdf
# => /path/al/doc.md
```

Con `--out-dir`:

```bash
tito-pdf doc.pdf --out-dir out
# => out/doc.md
```

Tablas:

```bash
tito-pdf doc.pdf --tables --out-dir out
# => out/doc.tables.md
```

Texto + tablas:

```bash
tito-pdf doc.pdf --all --out-dir out
```

## Modos
- `--mode robust` (default): OCR conservador + tablas estrictas
- `--mode fast`: sin OCR
- `--mode best`: fuerza OCR y reintenta tablas en modo lenient si no hay tablas en estricto

## Más documentación
- CLI (parámetros): [CLI]({{ "/docs/cli/" | relative_url }})
- Output contract: [Output]({{ "/docs/output/" | relative_url }})
- OCR: [OCR]({{ "/docs/ocr/" | relative_url }})
- Tablas: [Tables]({{ "/docs/tables/" | relative_url }})

Flags: `tito-pdf --help`
