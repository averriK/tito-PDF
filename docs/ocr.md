---
layout: default
title: OCR
permalink: /docs/ocr/
---

# OCR
`tito-pdf` can run OCR for PDFs using `ocrmypdf` (Python package + CLI), which in turn uses `tesseract`.

OCR is only relevant for **PDF** inputs.

## When you need OCR
OCR helps when:
- the PDF is a scanned document (images of text)
- the PDF has a “bad text layer” (garbled characters, missing words)

If the PDF already has a good text layer, OCR can be unnecessary work and sometimes makes output noisier.

## Dependencies
For OCR to run:
- `ocrmypdf` must be available (installed in the runtime venv by the repo installer)
- `tesseract` must be available on PATH (system dependency)

Recommended installs on macOS:

```bash
brew install tesseract
```

## How `ocrmypdf` is invoked (implementation detail)
`tito-pdf` prefers the `ocrmypdf` console entrypoint when it is available on PATH.

If the entrypoint is not on PATH but the Python package is installed, it falls back to:
- `python -m ocrmypdf ...`

Flags used:
- `--quiet`
- `--output-type pdf`
- and either:
  - `--skip-text` (default; conservative)
  - `--force-ocr` (when forced)

If OCR fails, `tito-pdf` prints a warning and continues with the non-OCR PDF.

## OCR behavior by mode
### `--mode robust` (default)
- OCR is **conservative**.
- If `ocrmypdf` is available, `tito-pdf` runs OCR with `--skip-text`.
  - That means: pages that already contain text are not OCR’d.

Good for:
- unknown PDFs where you want the best chance of getting readable output

### `--mode fast`
- OCR is disabled (unless you explicitly force it).

Good for:
- PDFs with a good text layer
- quick iterations

### `--mode best`
- OCR is forced (unless you explicitly disable it).

Good for:
- scanned PDFs
- PDFs where robust mode still misses text

## Explicit OCR flags
### `--no-ocr`
Disable OCR completely.

### `--force-ocr`
Force OCR even if the PDF already has a text layer.

Notes:
- If both `--no-ocr` and `--force-ocr` are set, `--no-ocr` wins.

## Failure behavior
If OCR fails for any reason:
- `tito-pdf` prints a warning.
- It continues extraction using the non-OCR PDF.

This is intentional:
- the tool should not hard-fail just because OCR is unavailable.

## Performance notes
OCR can be slow. When iterating:
- first try `--mode fast`
- or limit pages:

```bash
tito-pdf input.pdf --mode best --md-out out/input.md --max-pages 10
```

See: [Pipeline]({{ "/docs/pipeline/" | relative_url }}).
