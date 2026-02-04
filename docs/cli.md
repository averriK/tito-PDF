# CLI reference

`--help` is the source of truth for flags:

```bash
tito-pdf --help
```

## Metavars
In `--help`, these placeholders mean:
- `PATH`: a filesystem path (file path)
- `DIR`: a filesystem path (directory path)
- `N`: a number

## Arguments
- `input_path`: path to a `.pdf` or `.docx`

## Options
- `-h, --help`: show help and exit
- `-V, --version`: show version and exit
- `--mode {fast,robust,best}`: extraction mode
- `--md-out PATH`: write primary Markdown to `PATH`
- `--out-dir DIR`: convenience output directory (used only when no explicit output paths are set)
- `--raw-text-out PATH`: write extracted plaintext (UTF-8) to `PATH`
- `--tables-out PATH`: write extracted tables Markdown to `PATH`
- `--tables-audit-out PATH`: write tables audit JSON to `PATH` (requires `--tables-out`)
- `--assets-json PATH`: write assets/metrics JSON to `PATH`
- `--text`: convenience mode: write Markdown output
- `--tables`: convenience mode: write tables Markdown output
- `--all`: convenience mode: write Markdown + tables outputs
- `--tables-lenient`: increase table recall (more false positives)
- `--no-ocr`: disable OCR stage
- `--force-ocr`: force OCR even if the PDF already has text
- `--max-pages N`: limit pages processed (debug)
