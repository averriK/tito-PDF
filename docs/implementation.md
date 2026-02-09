---
layout: default
title: Implementation details
permalink: /docs/implementation/
---

# Implementation details
This page documents **code-level behavior** in `tito-pdf` (the Python script), including thresholds and heuristics.

- The CLI contract is still `tito-pdf --help`.
- The stable behavior contract is described in [Output contract]({{ "/docs/output/" | relative_url }}).
- This page is intentionally “low level”: it exists so maintainers can reason about why outputs look the way they do.

## Where logic lives
Key functions in the `tito-pdf` script:

- CLI + orchestration: `main()`
- Output mode resolution: `explicit_output_mode` block in `main()`
- PDF prep: `prepare_pdf()`
- OCR: `ocr_pdf()`
- PDF text extraction: `extract_lines_layout()` → `drop_repeated_headers_footers()` → `lines_to_markdown()` / `lines_to_text()`
- PDF tables: `extract_tables()` (plus `should_accept()` inside it)
- DOCX: `extract_docx_markdown()` / `extract_docx_text()` / `extract_docx_tables()`

## Output mode resolution (exact behavior)
`main()` computes:

- `md_out`, `raw_text_out`, `tables_out`, `tables_audit_out`, `assets_json_out`
- `explicit_output_mode = any([md_out, raw_text_out, tables_out, tables_audit_out, assets_json_out])`

### Explicit output mode
If `explicit_output_mode` is true:

- What is generated is determined *only* by which explicit paths are set:
  - `do_md = (md_out is not None)`
  - `do_raw_text = (raw_text_out is not None)`
  - `do_tables = (tables_out is not None) or (tables_audit_out is not None)`

- Validation rules:
  - If `tables_audit_out` is set but `tables_out` is missing → **error** (`--tables-audit-out requires --tables-out`).
  - If no content outputs are requested (md/raw/tables) → **error**.

- Convenience flags (`--text`, `--tables`, `--all`) are ignored.
- `--out-dir` is ignored.

### Convenience mode
If no explicit paths are set:

- `out_dir` defaults to `input_path.parent`, or uses `--out-dir` if provided.
- `do_md` and `do_tables` come from convenience toggles:
  - `--all` enables both
  - otherwise `--tables` enables tables
  - otherwise `--text` enables markdown
  - if none are provided, default is **Markdown only**

- Convenience output filenames are derived from `Path.stem`:
  - text: `<stem>.md`
  - tables: `<stem>.tables.md`

There is no convenience-mode plaintext output file; `--raw-text-out` is explicit-only.

## Mode + override resolution (exact mapping)
`main()` treats `--mode` as a high-level knob that sets defaults.

Inputs:
- `mode` ∈ `{fast, robust, best}`
- explicit override flags:
  - `--no-ocr`
  - `--force-ocr`
  - `--tables-lenient`

Resolution logic (as implemented):

- Start with `no_ocr = args.no_ocr`, `force_ocr = args.force_ocr`, `tables_lenient = args.tables_lenient`.
- `tables_auto_fallback = False`.

- If `mode == "fast"` and the user did **not** explicitly set `--no-ocr` or `--force-ocr`:
  - set `no_ocr = True`.

- If `mode == "best"` and the user did **not** explicitly set `--no-ocr` or `--force-ocr`:
  - set `force_ocr = True`.

- If `mode == "best"` and the user did **not** explicitly set `--tables-lenient`:
  - set `tables_auto_fallback = True`.

- If both `no_ocr` and `force_ocr` are true:
  - print a warning
  - force `force_ocr = False` (so `--no-ocr` wins).

## PDF preparation (`prepare_pdf`)
`prepare_pdf(input_pdf, output_pdf)` produces a normalized working copy for downstream parsing.

### `qpdf` step
- Detect `qpdf` via `shutil.which("qpdf")`.
- If missing: the run stops with an error (PDF conversion requires `qpdf`).
- Runs: `qpdf --decrypt input.pdf output.pdf`.
- If `qpdf` fails: the run stops with an error.

## OCR stage (`ocr_pdf`)
`ocr_pdf(input_pdf, output_pdf, force)`:

- Prefers `ocrmypdf` CLI entrypoint.
- If the entrypoint is missing but the Python package is installed:
  - falls back to `python -m ocrmypdf`.

Flags used:
- `--quiet`
- `--output-type pdf`
- either:
  - `--skip-text` (default)
  - or `--force-ocr` (when forced)

Failure behavior:
- If OCR fails, `tito-pdf` prints a warning and continues using the non-OCR PDF.

## PDF line extraction (`extract_lines_layout`)
PyMuPDF provides layout metadata.

Implementation notes:
- The extractor calls `page.get_text("dict")` and walks:
  - blocks → lines → spans
- It creates a `PdfLine` with:
  - `text`: normalized span text joined together
  - `size`: median of span sizes (if available)
  - `bbox`: the line bounding box from PyMuPDF
  - `bold`: `True` if any span font name contains “bold”

`--max-pages N` limits how many pages are processed.

## Header/footer dropping (`drop_repeated_headers_footers`)
This is a heuristic filter intended to remove repeated page furniture.

Rules:
- If the document has fewer than 3 pages:
  - only page numbers are removed.

- Otherwise:
  - candidate strings are counted when:
    - normalized length ≤ 80 characters
    - and they are near the top or bottom of the page:
      - top: `y1 <= 0.12 * page_h`
      - bottom: `y0 >= 0.88 * page_h`

- A string is dropped if it appears on at least:
  - `thresh = max(2, int(num_pages * 0.6))`

Page numbers:
- removed always when they match:
  - `^\d{1,4}$`
  - or `^page\s+\d{1,4}(\s+of\s+\d{1,4})?$` (case-insensitive)

## Markdown reconstruction (`lines_to_markdown`)
Lines are sorted in reading order:

- `(page, y0, x0)`

### Body font size inference (`infer_body_font_size`)
The “body size” is the mode of rounded font sizes from “normal” lines:
- ignores sizes <= 0 or > 72
- only considers lines where `len(text) >= 30`
- rounds sizes to the nearest 0.5

If nothing qualifies, body defaults to `12.0`.

### Heading detection (`_is_heading`)
A line is treated as a heading if:

- Length is between 2 and 140, and
- It is not a long sentence ending in a period:
  - reject if `text.endswith('.')` and `len(text) > 40`

Primary rule:
- `line.size >= body_size * 1.35`

Fallbacks (for OCR/uniform-font PDFs):
- bold line and `len(text) <= 80`
- centered line and `len(text) <= 80` and:
  - text is uppercase, or
  - matches a numbered heading like `1.2 Title`
- uppercase line where `5 <= len(text) <= 60`

Centered is defined as:
- the line center is within `0.12 * page_w` of the page center.

### Heading level (`_heading_level`)
Size-based levels:
- `>= 1.7 * body` → H1
- `>= 1.5 * body` → H2
- `>= 1.35 * body` → H3

Fallback numbering rule:
- if the text matches `^\d+(?:\.\d+){0,2}\s+...`:
  - count the dots (up to two)
  - return `min(4 + dots, 6)`

### List detection (`_is_list_item`)
A list item is detected if the line matches:
- bullet: `^[-*•]\s+\S+`
- numbered: `^\d+[\).]\s+\S+`

Normalization:
- numbered items are rewritten to `1. ...` (Markdown auto-numbering)
- bullets are rewritten to `- ...`

### Paragraph joining
Paragraphs are joined until a vertical gap indicates a new paragraph.

- New paragraph if the gap is greater than:
  - `max(6.0, body_size * 0.9)`

Hyphenation repair:
- if the current paragraph ends with `-` and the next line starts with a lowercase letter:
  - the hyphen is removed and the word is joined.

## Plaintext reconstruction (`lines_to_text`)
Plaintext export keeps paragraph joining and hyphenation repair but does not produce headings or lists.

Differences from Markdown:
- It flushes paragraphs on page breaks (page change always starts a new paragraph).

## Tables extraction (`extract_tables`)
This stage produces:
- tables Markdown
- tables audit JSON payload (in memory; written if requested)

### Strategy order (PDF)
1) PyMuPDF table finder
- always tries `lines/lines`
- in lenient mode, also tries `lines/text`, `text/lines`, `text/text`

2) Camelot (optional)
- tries `lattice` and `stream`

3) pdfplumber fallback
- strategy list mirrors the PyMuPDF strategy list

The function returns early when a strategy yields at least one accepted table.

### Table normalization + dedup
Deduplication is done by a content signature:
- normalize each cell via `_norm_text`
- hash the table content (sha1)

Tables with duplicate signatures are not emitted twice.

Markdown conversion rules:
- empty rows are dropped
- tables with < 2 columns are rejected
- if the header row is empty, it is replaced with `Col1..ColN`
- cells escape `|` and newlines are flattened

### Acceptance filters (exact thresholds)
The core filters live in `should_accept(...)`.

Hard size limits:
- reject `rows < 2` or `cols < 2`
- reject `cols > 30`
- reject `rows > 500`

Two-row sparse grids:
- if `rows == 2` and `cols >= 3`:
  - reject unless cell fill ratio is at least `0.90`

Sparsity:
- reject if `empty_ratio > 0.85`

Bounding box guards (when bbox is available):
- reject “tiny header/footer” blocks:
  - `height_ratio < 0.05` and `rows <= 6` and near top/bottom (`top_ratio < 0.12` or `bottom_ratio > 0.88`) and `digit_ratio < 0.35`

- reject “tiny sparse block” furniture:
  - `height_ratio < 0.05` and `area_ratio < 0.05` and `empty_ratio > 0.55` and `digit_ratio < 0.50`

PyMuPDF multi-column guard:
- for `tool == pymupdf` and `mode == pymupdf/lines/lines`:
  - if `width_ratio < 0.75`, reject unless:
    - `digit_ratio >= 0.60` and `empty_ratio <= 0.60` and `rows >= 4` and `cols >= 3`

Text-strategy guard:
- for modes containing `text`:
  - bbox must exist
  - reject page-like detections unless strongly numeric:
    - if `area_ratio > 0.60` or `height_ratio > 0.60` and `digit_ratio < 0.25` → reject
  - reject huge sparse page-like grids:
    - if `height_ratio > 0.85` and `empty_ratio > 0.55` and `digit_ratio < 0.35` → reject
  - reject narrow tables:
    - if `width_ratio < 0.75` → reject

Near-full-page hard stop:
- if `area_ratio > 0.92` and `height_ratio > 0.85` → reject

### Audit JSON fields
The tables audit JSON includes:
- `rows`, `cols`, `cells_total`, `cells_nonempty`
- `empty_ratio`, `digit_ratio`
- `sha1` (dedup signature)
- bbox ratios when available: `width_ratio`, `height_ratio`, `area_ratio`, `top_ratio`, `bottom_ratio`
- `tool` and `mode`

## DOCX extraction details
DOCX uses `python-docx`.

### Headings
DOCX headings are detected by paragraph style name matching:
- `^Heading\s+(\d+)\b`

The level is clamped to 1..6 and mapped to Markdown headings.

### Tables
Tables are converted to Markdown using the first row as the header and a `---` separator row.

## Assets JSON (toolchain capture)
When `--assets-json` is requested, `tito-pdf` captures:
- system tool paths + versions (best-effort)
- Python package versions (best-effort)
- stage timings and basic metrics

System tool versions are read by executing `--version` and capturing the first line (with a short timeout).

See: [Assets JSON]({{ "/docs/assets-json/" | relative_url }}).
