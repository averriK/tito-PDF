---
layout: default
title: Tables
permalink: /docs/tables/
---

# Tables
`tito-pdf` can extract tables from PDFs and DOCX and write them as Markdown.

Tables are intentionally treated as **optional** output:
- table extraction is harder and noisier than text extraction
- strict heuristics reduce false positives

## Outputs
To request tables you either:

- use convenience mode:

```bash
tito-pdf input.pdf --tables --out-dir out
# => out/input.tables.md
```

- or use explicit output paths:

```bash
tito-pdf input.pdf \
  --tables-out out/input.tables.md \
  --tables-audit-out out/input.tables.audit.json
```

Notes:
- `--tables-audit-out` requires `--tables-out`.
- If no tables are detected, the tables Markdown output is:
  - `(No tables detected.)\n`

## Strategy order (PDF)
For PDFs, table extraction uses multiple deterministic strategies.

Order:
1. PyMuPDF table finder (primary)
2. Camelot (optional; only if installed)
3. pdfplumber (fallback)

The implementation stops early if an earlier strategy produces at least one accepted table.

### 1) PyMuPDF (primary)
PyMuPDF is already required for layout-aware text extraction, so it is the primary table detector.

Strict mode:
- uses `Page.find_tables(vertical_strategy="lines", horizontal_strategy="lines")`

Lenient mode:
- also tries combinations involving `"text"` strategies.

### 2) Camelot (optional)
If `camelot` is installed in the runtime environment, `tito-pdf` will try it.

Notes:
- Camelot is **not** installed by default in `requirements.txt`.
- It can work well for vector tables, but adds heavier dependencies.

### 3) pdfplumber (fallback)
If strict PyMuPDF fails to produce tables, `tito-pdf` may fall back to pdfplumber.

## Strict vs lenient
Strict is the default because it avoids many false positives.

Ways to get lenient behavior:

1) Explicitly:

```bash
tito-pdf input.pdf --tables --out-dir out --tables-lenient
```

2) Automatically (best mode fallback):

```bash
tito-pdf input.pdf --tables --out-dir out --mode best
```

In `--mode best`, if strict detection yields **zero accepted tables**, `tito-pdf` retries in lenient mode.

## Why false positives happen
Common false positives:
- multi-column academic PDFs, where a “table finder” can interpret prose columns as a grid
- title blocks and page furniture (small sparse grids)
- header/footer regions

`tito-pdf` combats these with acceptance filters.

## Acceptance filters (what gets rejected)
The goal is to accept “table-like” structures and reject page furniture.

Examples of hard filters:
- must be at least 2 rows × 2 columns
- reject very sparse grids (mostly empty)
- reject extremely large tables (too many rows/cols)
- reject tiny header/footer blocks
- reject near-full-page detections (almost always a false positive)

There are also extra guards for:
- narrow single-column detections from text-based strategies

These filters are intentionally conservative.

### Implementation details (current heuristics)
The exact thresholds live in the `should_accept(...)` helper.

Some key rules (as of the current implementation):
- Size limits:
  - reject `rows < 2` or `cols < 2`
  - reject `cols > 30`
  - reject `rows > 500`
- Sparsity:
  - reject tables with `empty_ratio > 0.85`
  - special case: for 2-row grids with 3+ columns, reject unless ~fully populated
- Bounding box guards (when bbox is available):
  - reject tiny header/footer blocks (short height, near top/bottom, low numeric density)
  - reject tiny sparse blocks (common in page furniture)
  - reject near-full-page detections (`area_ratio` and `height_ratio` both very high)
- Multi-column PDF guard:
  - PyMuPDF detections confined to a single text column (`width_ratio < ~0.75`) are treated as suspicious unless strongly table-like
- Text-strategy guard:
  - for text-based strategies, require a reasonable bbox (wide enough; not page-like unless strongly numeric)

These rules are designed to minimize “tables that are actually prose”.

## Audit JSON (how to read it)
With `--tables-audit-out`, you get a JSON payload describing accepted tables.

Fields you’ll commonly see:
- `index`: table number in the output
- `page`: PDF page number (PDF only)
- `tool`: `pymupdf`, `camelot`, or `pdfplumber`
- `mode`: extractor mode string (e.g. `pymupdf/lines/lines`)
- `rows`, `cols`
- `empty_ratio`: how sparse the table is
- `digit_ratio`: how numeric the table looks
- `sha1`: content signature used for deduplication

Some extractors also include bounding-box ratios (width/height/area relative to page):
- `width_ratio`: table width / page width
- `height_ratio`: table height / page height
- `area_ratio`: table area / page area
- `top_ratio`, `bottom_ratio`: vertical position (useful for header/footer filtering)

## Debugging tips
- Limit pages while iterating:

```bash
tito-pdf input.pdf --tables --out-dir out --max-pages 10
```

- Use `--tables-audit-out` to see what the extractor accepted.
- If you get no tables, try `--mode best` or `--tables-lenient`.
- If you get too many false positives, go back to strict mode (disable lenient).

## DOCX tables
DOCX tables are extracted via `python-docx`.

- The output is deterministic.
- The audit is simple (table index, rows/cols).

See: [Pipeline]({{ "/docs/pipeline/" | relative_url }}).
