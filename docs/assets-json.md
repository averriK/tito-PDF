---
layout: default
title: Assets JSON
permalink: /docs/assets-json/
---

# Assets JSON
`tito-pdf` can write a compact assets/metrics JSON file via `--assets-json`.

Example:

```bash
tito-pdf input.pdf \
  --md-out out/input.md \
  --tables-out out/input.tables.md \
  --tables-audit-out out/input.tables.audit.json \
  --assets-json out/input.assets.json
```

Why this exists:
- Orchestrators need a stable, small “receipt” describing what happened.
- Deterministic tools still depend on toolchain versions; capturing them helps with debugging.

## Contract (stable keys)
The following keys are intended to be stable:

- `schema_version` = `1`
- `tool` = `"tito-pdf"`
- Timestamps:
  - `started_at_utc`
  - `finished_at_utc`
- `duration_ms`
- Run parameters:
  - `mode`
  - `input_kind` (`pdf` or `docx`)
  - `input_path`
  - `input_size_bytes`
- `timings_ms` (stage durations, best-effort)
- `metrics` (object)
  - at minimum: `raw_text_bytes`, `raw_text_lines`, `tables_count`

## Outputs (paths that were written)
If outputs were written, `tito-pdf` includes an `outputs` object with paths.

Example structure:
- `outputs.text_md`
- `outputs.raw_text`
- `outputs.tables_md`
- `outputs.tables_audit_json`

Compatibility note:
- Some outputs are also duplicated as legacy top-level keys (e.g. `raw_text_out`, `tables_out`, `tables_audit_out`).

## Toolchain section
If available, `tito-pdf` includes a `toolchain` object with:
- Python executable + version
- Platform string
- System tools (paths + `--version` output for):
  - `qpdf`
  - Ghostscript (`gs` / `gswin64c`)
  - `ocrmypdf`
  - `tesseract`
- Python package versions for:
  - PyMuPDF
  - pdfplumber
  - pandas
  - ocrmypdf
  - python-docx

This is best-effort:
- if a tool is missing, the path/version may be `null`.

## Tips
- If you are investigating inconsistent output across machines, always enable `--assets-json`.
- Keep `schema_version` stable; if you change the schema, bump the version explicitly and update docs/tests.
