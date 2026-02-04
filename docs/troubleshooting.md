# Troubleshooting

## Missing Python libraries
If you see import errors for `fitz`/PyMuPDF or `pdfplumber`, ensure the runtime environment has the repo dependencies installed.

## OCR issues
Symptoms:
- `ocrmypdf` not found
- `tesseract` missing
- OCR warnings

Actions:
- For fast runs / PDFs with good text: `--mode fast` or `--no-ocr`
- For scanned PDFs: `--mode best` or `--force-ocr` (requires `tesseract`)

## No tables detected
Actions (recommended order):
1. `--mode best` (enables lenient fallback only if strict finds none)
2. `--tables-lenient`
3. Limit pages to debug: `--max-pages 10`

## Performance
- Try `--mode fast`
- Try `--max-pages N` to reduce runtime while iterating
