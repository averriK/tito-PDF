---
layout: default
title: Troubleshooting
permalink: /docs/troubleshooting/
---

# Troubleshooting
This page focuses on common failure modes and the shortest retry path.

## 0) Sanity check: are you running the right binary?
If you are seeing help output with env-var-looking defaults, you are probably running **`tito`** (the orchestrator), not `tito-pdf`.

Commands:

```bash
command -v tito
command -v tito-pdf
tito-pdf --help
```

## Missing Python libraries (PyMuPDF / pdfplumber / python-docx)
Symptoms:
- Import error for `fitz` (PyMuPDF)
- Import error for `pdfplumber`
- Import error for `docx` (python-docx)

If you installed via the repo installer, these should be present in the runtime venv.

If you are running from source in a dev venv:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## OCR issues
### Symptoms
- OCR warnings
- `tesseract` missing
- OCR too slow

### Fixes / retries
- If the PDF has good text: skip OCR

```bash
tito-pdf input.pdf --mode fast --md-out out/input.md
```

- If the PDF is scanned: force OCR

```bash
tito-pdf input.pdf --mode best --md-out out/input.md
```

- If OCR is noisy or failing but you can live without it:

```bash
tito-pdf input.pdf --no-ocr --md-out out/input.md
```

See: [OCR]({{ "/docs/ocr/" | relative_url }}).

## No tables detected
The tables output `(No tables detected.)` can be correct.

Retry order (recommended):
1) best mode (auto lenient fallback)

```bash
tito-pdf input.pdf --tables --out-dir out --mode best
```

2) explicitly enable lenient tables

```bash
tito-pdf input.pdf --tables --out-dir out --tables-lenient
```

3) limit pages while iterating

```bash
tito-pdf input.pdf --tables --out-dir out --mode best --max-pages 10
```

See: [Tables]({{ "/docs/tables/" | relative_url }}).

## Too many table false positives
If you enabled lenient mode and got junk tables:
- disable lenient detection
- limit pages

```bash
tito-pdf input.pdf --tables --out-dir out --mode robust --max-pages 10
```

## Performance
Fastest first:
- `--mode fast` (disables OCR)
- `--max-pages N` (debug/iteration)

Example:

```bash
tito-pdf input.pdf --mode fast --md-out out/input.md --max-pages 10
```

## Inconsistent output across machines
Even deterministic tools can vary with toolchain versions.

To capture forensic info, enable assets JSON:

```bash
tito-pdf input.pdf --md-out out/input.md --assets-json out/input.assets.json
```

See: [Assets JSON]({{ "/docs/assets-json/" | relative_url }}).
