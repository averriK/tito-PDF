---
layout: default
title: Usage
permalink: /docs/usage/
---

# Usage
`tito-pdf` writes outputs to files. It prints short status lines to stderr (e.g. `Wrote: ...` and `OK`).

## Recommended: explicit primary Markdown output
Use `--md-out` so the output location is unambiguous and scriptable:

```bash
tito-pdf input.pdf --md-out out/input.md
```

DOCX:

```bash
tito-pdf input.docx --md-out out/input.md
```

## Optional: raw text output (integration)
If you need a plaintext stream for downstream slicing/cleanup:

```bash
tito-pdf input.pdf \
  --mode fast \
  --md-out out/input.md \
  --raw-text-out out/input.raw.txt
```

## Convenience mode (human workflow)
If you **do not** provide any explicit output paths, `tito-pdf` writes next to the input file by default:

```bash
tito-pdf /path/to/input.pdf
# => /path/to/input.md
```

Write into a directory:

```bash
tito-pdf /path/to/input.pdf --out-dir out
# => out/input.md
```

Tables in convenience mode:

```bash
tito-pdf input.pdf --tables --out-dir out
# => out/input.tables.md
```

Tables only (explicit paths):

```bash
tito-pdf input.pdf \
  --mode fast \
  --tables-out out/input.tables.md \
  --tables-audit-out out/input.tables.audit.json
```

Text + tables in convenience mode:

```bash
tito-pdf input.pdf --all --out-dir out
# => out/input.md + out/input.tables.md
```

## Explicit output paths (integration mode)
Any explicit output path flag enables **explicit output mode**.

In explicit output mode:
- `tito-pdf` writes **only** to the paths you provide.
- `--out-dir` and the convenience toggles (`--text`, `--tables`, `--all`) are ignored.

Example:

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
- `--assets-json` is a companion output; you must also request at least one content output (`--md-out` and/or `--raw-text-out` and/or `--tables-out`).

## Choosing a mode
`tito-pdf` exposes a single high-level knob: `--mode`.

- `--mode robust` (default)
  - Conservative OCR behavior (`ocrmypdf --skip-text` when available).
  - Strict table detection.
  - Good default when you don’t know the PDF quality.

- `--mode fast`
  - Disables OCR.
  - Best for PDFs with a good text layer and for quick iteration.

- `--mode best`
  - Forces OCR.
  - If strict table detection finds no tables, it automatically retries with lenient table detection.
  - Best for scanned PDFs or “bad text layer” PDFs.

Overrides (explicit flags win over `--mode`):
- `--no-ocr`
- `--force-ocr`
- `--tables-lenient`

## Debug / iteration: limit pages
If you are debugging performance or table false positives, limit pages:

```bash
tito-pdf input.pdf --mode fast --md-out out/input.md --max-pages 10
```

## Next: learn the flags
- [CLI reference]({{ "/docs/cli/" | relative_url }})
- [Output contract]({{ "/docs/output/" | relative_url }})
- [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }})
