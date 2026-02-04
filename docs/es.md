# tito-pdf (guía rápida)

`tito-pdf` convierte `.pdf` / `.docx` a Markdown (y opcionalmente extrae tablas), de forma local/determinística.

## Recomendado (salida explícita)

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

Flags: `tito-pdf --help`
