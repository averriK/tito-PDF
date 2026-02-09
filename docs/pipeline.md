---
layout: default
title: Pipeline
permalink: /docs/pipeline/
---

# Pipeline
This page documents the internal stages of `tito-pdf` as implemented in the `tito-pdf` script.

Goals:
- Describe the real pipeline stages implemented in the `tito-pdf` script.
- Explain why each stage exists and what it outputs.
- Keep the output contract stable (explicit outputs are authoritative; no extra output folders).

## High-level flow
`tito-pdf` converts one input document per invocation.

Conceptually:

- Validate input path and infer kind: PDF or DOCX.
- Resolve output mode:
  - Explicit output mode (write only to the requested paths), or
  - Convenience mode (derive `<stem>.md` / `<stem>.tables.md`).
- Run pipeline stages.
- Write outputs atomically.
- Optionally write assets/metrics JSON.

## PDF pipeline
### 1) Prepare PDF (`prepare_pdf`)
Purpose: create a working copy that is easier for downstream parsers.

Implementation:
- Requires `qpdf` on PATH.
- Runs `qpdf --decrypt input.pdf prepared.pdf`.
- If `qpdf` is missing or the command fails: the run stops with an error.

Why `qpdf` exists in the pipeline:
- Some PDFs are encrypted or have structural quirks.
- Normalization improves the chance that PyMuPDF and table extractors can read the file reliably.

### 2) OCR (`ocr_pdf`)
Purpose: improve extraction quality for scanned PDFs or PDFs with a bad text layer.

Tool: `ocrmypdf` (Python package + CLI) + `tesseract` (system tool).

Behavior:
- If `ocrmypdf` is available, `tito-pdf` runs it.
- Default OCR behavior is conservative:
  - It uses `ocrmypdf --skip-text` so that text-based PDFs are not rewritten unnecessarily.
- Forced OCR uses `ocrmypdf --force-ocr`.

Invocation details:
- It prefers the `ocrmypdf` CLI entrypoint.
- If the entrypoint is not on PATH but the Python package is installed, it falls back to `python -m ocrmypdf`.
- It passes `--quiet` and `--output-type pdf` to keep output stable.

Failure mode:
- If OCR fails, `tito-pdf` prints a warning and continues using the non-OCR PDF.

See: [OCR]({{ "/docs/ocr/" | relative_url }}).

### 3) Layout-aware text extraction (`extract_lines_layout`)
Purpose: get text with position and font metadata so we can make better Markdown than “just text”.

Implementation details:
- The extraction walks pages and calls `page.get_text("dict")`.
- Lines are later sorted in reading order by `(page, y0, x0)`.
- `--max-pages N` limits how many pages are processed in this stage.

Tool: PyMuPDF (`fitz`).

What we extract:
- Per line, we record:
  - page number
  - normalized text
  - font size (median of span sizes)
  - bounding box (`x0,y0,x1,y1`)
  - page width/height
  - bold heuristic (font name contains “bold”)

### 4) Header/footer dropping (`drop_repeated_headers_footers`)
Purpose: remove repeated page furniture that would pollute the Markdown.

Heuristic:
- If the document has < 3 pages, we only drop page numbers.
- Otherwise we count short strings that appear near the top/bottom of pages.
- Anything that appears on ~60% of pages is treated as a header/footer and removed.

### 5) Markdown reconstruction (`lines_to_markdown`)
Purpose: convert positioned lines into best-effort Markdown.

Key heuristics:
- Infer a “body font size” from the mode of typical line sizes.
- Headings:
  - Larger font sizes become `#`, `##`, `###`.
  - OCR/uniform-font fallbacks: bold lines, centered uppercase, or numbered headings.
- Lists:
  - bullets `- * •` and numbered lists like `1)` / `1.` are normalized.
- Paragraph joining:
  - lines are joined until a large vertical gap implies a new paragraph.
  - basic hyphenation repair joins `foo-` + `bar` => `foobar`.

### 6) Plaintext export (`lines_to_text`)
Purpose: provide a raw, non-Markdown text stream for downstream tools.

Compared to Markdown:
- No headings, no list normalization.
- Still uses paragraph joining and hyphenation repair.

### 7) Table extraction (`extract_tables`)
Purpose: extract tables deterministically without an LLM.

Strategy order:
1. **PyMuPDF table finder** (primary)
2. **Camelot** (optional; only if installed)
3. **pdfplumber** (fallback)

Strict vs lenient:
- Strict uses PyMuPDF `find_tables(lines/lines)` and filters aggressively.
- Lenient enables text-based strategies (higher recall, more false positives).

Output:
- Tables Markdown (`--tables-out` or `<stem>.tables.md`)
- Tables audit JSON (`--tables-audit-out`)

See: [Tables]({{ "/docs/tables/" | relative_url }}).

## DOCX pipeline
Tool: `python-docx`.

### 1) Markdown extraction (`extract_docx_markdown`)
- Paragraphs are emitted as Markdown paragraphs.
- DOCX heading styles (`Heading 1`..`Heading 6`) become Markdown headings.

### 2) Raw text extraction (`extract_docx_text`)
- Concatenates paragraphs as plaintext.

### 3) Table extraction (`extract_docx_tables`)
- Extracts DOCX tables and converts them to Markdown tables.
- Produces a small audit list (tool, table index, rows, cols).

## Output writing (atomic)
All outputs are written after extraction succeeds.

Implementation detail:
- Each file is written to a `*.tmp` file and then renamed into place.

Benefits:
- Avoids leaving a misleading empty output if extraction fails mid-run.

