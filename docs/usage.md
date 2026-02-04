# Usage

## Primary Markdown (recommended)

```bash
tito-pdf input.pdf --md-out out/input.md
```

DOCX:

```bash
tito-pdf input.docx --md-out out/input.md
```

## Convenience mode
If you don't provide any explicit output paths, `tito-pdf` writes next to the input file by default:

```bash
tito-pdf /path/to/input.pdf
# => /path/to/input.md
```

Write into a directory:

```bash
tito-pdf /path/to/input.pdf --out-dir out
# => out/input.md
```

Tables:

```bash
tito-pdf input.pdf --tables --out-dir out
# => out/input.tables.md
```

Text + tables:

```bash
tito-pdf input.pdf --all --out-dir out
# => out/input.md + out/input.tables.md
```

## Explicit output paths (integration)
Any explicit output path flag enables explicit output mode (writes only to the provided paths):

```bash
tito-pdf input.pdf \
  --mode fast \
  --md-out out/input.md \
  --raw-text-out out/input.raw.txt \
  --tables-out out/input.tables.md \
  --tables-audit-out out/input.tables.audit.json \
  --assets-json out/input.assets.json
```

Notes:
- `--tables-audit-out` requires `--tables-out`.
- `--out-dir` is ignored in explicit output mode.

## Modes
- `--mode robust` (default): OCR conservative + tables strict
- `--mode fast`: disables OCR
- `--mode best`: forces OCR and retries tables with lenient detection if strict finds none
