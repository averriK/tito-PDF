---
layout: default
title: Output contract
permalink: /docs/output/
---

# Output contract
`tito-pdf` intentionally has a small, stable output contract. The same rules apply to PDFs and DOCX (except where explicitly noted).

## Output styles (two modes)
`tito-pdf` has two output styles.

### 1) Explicit output paths (recommended / integration)
If **any** of these flags are provided:
- `--md-out PATH`
- `--raw-text-out PATH`
- `--tables-out PATH`
- `--tables-audit-out PATH` (requires `--tables-out`)
- `--assets-json PATH`

…then `tito-pdf` enters **explicit output mode**.

In explicit output mode:
- Outputs are written **exactly** to the paths you provide.
- Parent directories are created.
- Writes are atomic: the tool writes a temp file (`.tmp`) then renames it into place.
- No extra output folders are created.
- `--out-dir` and convenience flags (`--text`, `--tables`, `--all`) are ignored.

### 2) Convenience mode (no explicit output paths)
If you do not provide any explicit output paths, deliverables follow the TITO folder convention:
- Outputs go to `<out-dir>/md/` (default `out-dir` is CWD).
- Naming: `md/<id>.retrieve.md` and `md/<id>.retrieve.tables.md`.
- `--id ID` sets the output prefix (defaults to input filename stem if omitted).
- `--tables` or `--all` also writes `<id>.retrieve.tables.md`.
- `--keep-sessions` preserves intermediate files in `sessions/run-YYYYMMDD_HHMMSS/`.

## Outputs (what each file contains)
### Primary Markdown (`--md-out` or `md/<id>.retrieve.md`)
Best-effort Markdown reconstruction from the document content.

Notes:
- PDF output quality depends heavily on the PDF text layer, fonts, and layout.
- Headings and lists are inferred heuristically.

### Raw text (`--raw-text-out`)
Plaintext (UTF-8). This is intended for downstream slicing/cleanup tools that prefer raw text.

### Tables Markdown (`--tables-out` or `md/<id>.retrieve.tables.md`)
A Markdown file containing one or more tables.

Format notes:
- For PDFs, extracted tables are labeled with page numbers: `## Table 1 (page N)`.
- For DOCX, extracted tables are labeled without pages: `## Table 1`.
- If no tables are detected, the output is:
  - `(No tables detected.)\n`

### Tables audit JSON (`--tables-audit-out`)
A JSON file describing the accepted tables.

Rules:
- Requires `--tables-out`.

The audit is intentionally “machine friendly”:
- Each accepted table includes basic stats (rows/cols, sparsity, etc.).
- Some extractors also include bounding-box ratios.

### Assets JSON (`--assets-json`)
A compact JSON payload with runtime metadata, timings, and metrics.

Contract notes:
- `schema_version == 1`
- `tool == "tito-pdf"`

See: [Assets JSON]({{ "/docs/assets-json/" | relative_url }}).

## Intermediates
Intermediates (prepared PDFs / OCR outputs) are stored in a temporary working directory and deleted by default.

To preserve intermediates for debugging/audit:
- Use `--keep-sessions` to create `sessions/run-YYYYMMDD_HHMMSS/` with prepared.pdf, ocr.pdf, etc.

Deliverables always go to `md/`; intermediates go to `sessions/` only when requested.
