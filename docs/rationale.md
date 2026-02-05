---
layout: default
title: Design rationale
permalink: /docs/rationale/
---

# Design rationale
This page answers a practical question:

> Why does `tito-pdf` use multiple tools/libraries instead of “one Python helper”?

Short answer: because PDF/DOCX conversion is not one problem.

- PDF text extraction
- OCR for scanned PDFs
- Table detection
- Decryption/normalization of broken PDFs

…are separate failure modes, and no single library is best-in-class for all of them.

This repo is intentionally conservative:
- deterministic/offline (no LLM, no network)
- robust via fallbacks
- stable output contract

## What this code is
`tito-pdf` is a **single-document converter**.

Inputs:
- `.pdf`
- `.docx`

Outputs (optional, user-controlled):
- primary Markdown (`--md-out` or convenience `<stem>.md`)
- plaintext (`--raw-text-out`)
- tables Markdown (`--tables-out` or `<stem>.tables.md`)
- tables audit JSON (`--tables-audit-out`, requires `--tables-out`)
- assets/metrics JSON (`--assets-json`)

Key contracts implemented in `main()`:
- explicit output mode vs convenience mode (`explicit_output_mode`)
- atomic writes (`_write_text_atomic`, `_write_json_atomic`)
- intermediates in a temporary working directory (no `sessions/`)

## Why the code is a single script (repo layout)
The entrypoint is `tito-pdf` (one Python file) on purpose:
- The installer copies a single script into a runtime directory.
- Keeping logic in one file avoids “import graph” problems in installed environments.

Internally, the script still has multiple helpers (functions) to keep stages separated.

## Why multiple external tools / libraries exist
### 1) `qpdf` (system tool)
Used in `prepare_pdf()`.

Problem it solves:
- Some PDFs are encrypted/partially protected or structurally odd.
- Many PDF parsers fail to open such files reliably.

What `tito-pdf` does:
- best-effort `qpdf --decrypt` into a working file
- if it fails, it falls back to copying the original PDF

Why not do this “pure Python”?
- PDF encryption/decryption/normalization is a deep rabbit hole.
- `qpdf` is the standard, battle-tested tool for this job.

### 2) Ghostscript (`gs` / `gswin64c`) (system tool)
Used in `prepare_pdf()`.

Problem it solves:
- If OCR is disabled, embedded raster images are often dead weight.
- Large image-heavy PDFs can slow down parsing.

What `tito-pdf` does:
- when OCR is disabled, it optionally rewrites the PDF with `-dFILTERIMAGE`.

Important limitation:
- This can remove content that only exists as images.
- That is why the code only strips images when OCR is disabled.

### 3) `ocrmypdf` + `tesseract` (OCR toolchain)
Used in `ocr_pdf()`.

Problem it solves:
- Scanned PDFs have no text layer.
- To extract text deterministically, you need OCR.

Why `ocrmypdf`?
- It produces a real PDF output (with a text layer).
- It is stable, deterministic, and widely used.

What `tito-pdf` does:
- prefers `ocrmypdf` CLI if available
- falls back to `python -m ocrmypdf` if the package is installed but the entrypoint is missing
- uses `--skip-text` by default (conservative) and `--force-ocr` when forced
- if OCR fails, it warns and continues (tool should still be usable without OCR)

Why not OCR in pure Python?
- OCR quality depends on mature engines and language data.
- `tesseract` is the standard engine; `ocrmypdf` orchestrates PDF-level OCR robustly.

### 4) PyMuPDF (`fitz`) (Python library)
Used in `extract_lines_layout()` and also the primary table finder.

Problems it solves:
- Fast PDF parsing.
- Layout-aware extraction (font sizes, bounding boxes) needed to infer headings and lists.

Why not `pdfplumber` for everything?
- `pdfplumber` is excellent, but tends to be slower and is not the best tool for layout-driven Markdown heuristics.
- PyMuPDF is already required for the text pipeline; using it for tables first keeps the dependency set minimal.

### 5) Multiple table extractors (PyMuPDF + optional Camelot + pdfplumber)
Used in `extract_tables()`.

Problem it solves:
- Table detection is unreliable across PDFs.
- Different libraries fail in different ways.

What `tito-pdf` does:
- Strategy order:
  1) PyMuPDF table finder (primary)
  2) Camelot (optional)
  3) pdfplumber (fallback)

Why the “stop early” behavior?
- Determinism and predictability: once a strategy produces accepted tables, do not mix strategies unless needed.

Why Camelot is optional:
- It can be very effective for some vector tables.
- It adds heavier dependencies (and often native/system requirements).

Why strict vs lenient?
- Strict reduces false positives (multi-column prose mis-detected as tables).
- Lenient increases recall but can generate junk.

This is reflected in the code:
- strict is default
- `--tables-lenient` enables more aggressive strategies
- `--mode best` triggers an automatic lenient retry only when strict produces zero accepted tables (`tables_auto_fallback`)

### 6) `python-docx` (DOCX parsing)
DOCX is not PDF.

Problem it solves:
- `.docx` is a zipped XML format.

What `tito-pdf` does:
- extracts paragraphs + headings + tables deterministically

## Why multiple internal helpers exist
This script is a pipeline.

Separation into functions (e.g. `prepare_pdf()`, `ocr_pdf()`, `extract_lines_layout()`, `extract_tables()`) exists so that:
- each stage has a single responsibility
- stage timings can be recorded in assets JSON
- failures can degrade gracefully (e.g. OCR failing should not kill text extraction)

## How parameters map to implementation
### `--mode`
`--mode` sets sensible defaults:
- `fast`: disables OCR
- `robust`: conservative OCR
- `best`: force OCR + optional tables auto-fallback to lenient

Explicit flags win:
- `--no-ocr`, `--force-ocr`, `--tables-lenient`

### Output mode (explicit vs convenience)
If you set any explicit output path, the tool enters explicit output mode.

Design intent:
- integration/orchestrators need exact file paths and must not get surprise folders

### Why `--tables-audit-out` requires `--tables-out`
The audit is a companion to the tables Markdown file; the contract enforces they move together.

### Why you cannot request only `--assets-json`
Assets JSON is a companion “receipt”; the implementation requires at least one content output to be requested.

## What to read in the source
Jump points in `tito-pdf`:
- `main()` (arg parsing, output-mode resolution, mode logic)
- `prepare_pdf()`
- `ocr_pdf()`
- `extract_lines_layout()` + `lines_to_markdown()`
- `extract_tables()` + `should_accept()`

See also:
- [Pipeline]({{ "/docs/pipeline/" | relative_url }})
- [CLI]({{ "/docs/cli/" | relative_url }})
- [Output contract]({{ "/docs/output/" | relative_url }})
