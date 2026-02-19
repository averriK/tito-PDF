---
layout: default
title: CLI reference
permalink: /docs/cli/
---

# CLI reference
The installed `tito-pdf --help` output is the source of truth for flags.

```bash
tito-pdf --help
```

This page explains every parameter, including interactions that are hard to express in `--help`.

## Metavars
In `--help`, placeholders mean:
- `PATH`: a filesystem path (file path)
- `DIR`: a filesystem path (directory path)
- `N`: a number

## Positional argument
### `input_path`
Path to a `.pdf` or `.docx`.

Rules:
- Must exist on disk.
- Type is inferred from the extension (`.pdf` or `.docx`).

## Version
### `-V, --version`
Prints a single line version header and exits.

## Mode (high level)
### `--mode {fast,robust,best}`
A convenience knob that maps to lower-level OCR/tables behavior.

- `robust` (default)
  - OCR: conservative (attempt OCR with `ocrmypdf --skip-text` when available)
  - Tables: strict

- `fast`
  - OCR: disabled (unless you explicitly force OCR)
  - Tables: strict

- `best`
  - OCR: forced (unless you explicitly disable OCR)
  - Tables: strict first; if no tables are accepted, retry with lenient table detection

Important: explicit flags win over `--mode`:
- `--no-ocr` and `--force-ocr` override OCR behavior.
- `--tables-lenient` overrides the table strict/lenient choice.

## Output selection: explicit vs convenience
`tito-pdf` has two output styles:

1) Explicit output mode
Triggered when **any** explicit output path is set:
- `--md-out PATH`
- `--raw-text-out PATH`
- `--tables-out PATH`
- `--tables-audit-out PATH`
- `--assets-json PATH`

In explicit output mode:
- `tito-pdf` writes **only** to the provided paths.
- `--out-dir` is ignored.
- convenience toggles (`--text`, `--tables`, `--all`) are ignored.

2) Convenience mode
Used when **no** explicit output paths are set.

In convenience mode (TITO-aligned folder structure):
- Deliverables go to `<out-dir>/md/` (default `out-dir` is CWD).
- Naming: `md/<id>.retrieve.md` and `md/<id>.retrieve.tables.md`.
- `--id ID` sets the output prefix (defaults to input filename stem if omitted).
- `--tables` or `--all` adds `<id>.retrieve.tables.md`.
- `--keep-sessions` preserves intermediate files in `sessions/run-YYYYMMDD_HHMMSS/`.

## Output paths (explicit)
### `--md-out PATH`
Write primary Markdown output to `PATH`.

Notes:
- Parent directories are created.
- The write is atomic (write a temp file then rename).

### `--raw-text-out PATH`
Write extracted plaintext (UTF-8) to `PATH`.

Why it exists:
- downstream slicing/cleanup often prefers plaintext over Markdown.

### `--tables-out PATH`
Write extracted tables as Markdown to `PATH`.

Notes:
- When no tables are detected, the output is the literal string `(No tables detected.)` followed by a newline.

### `--tables-audit-out PATH`
Write a JSON audit describing accepted tables.

Rules:
- Requires `--tables-out PATH`.

### `--assets-json PATH`
Write a JSON payload with runtime metadata and metrics.

Important:
- `--assets-json` is a companion output; you must also request at least one content output (`--md-out` and/or `--raw-text-out` and/or `--tables-out`).

See: [Assets JSON]({{ "/docs/assets-json/" | relative_url }}).

## Convenience directory
### `--out-dir DIR`
Base directory for deliverables.

- Deliverables go to `<out-dir>/md/`.
- Default: current working directory.
- Used only when **no explicit output paths** are provided.
- If you provide any explicit output path, `--out-dir` is ignored.

### `--id ID`
Identifier for output filenames.

- Outputs: `md/<id>.retrieve.md`, `md/<id>.retrieve.tables.md`.
- Default: input filename stem (with a warning).

### `--keep-sessions`
Preserve intermediate files in `sessions/run-YYYYMMDD_HHMMSS/`.

- Useful for debugging and audit.
- Intermediates include: prepared.pdf, ocr.pdf.

## Convenience toggles
These toggles only matter in convenience mode.

### `--text`
Write Markdown output.

- In convenience mode, Markdown is already the default.
- This flag exists for symmetry with `--tables` / `--all`.

### `--tables`
Write tables Markdown output (`<stem>.tables.md`).

### `--all`
Write both Markdown and tables Markdown.

## Tables behavior
### `--tables-lenient`
Enable text-based table detection (higher recall, more false positives).

Notes:
- In `--mode best`, lenient tables can be enabled automatically as a fallback when strict finds no tables.

See: [Tables]({{ "/docs/tables/" | relative_url }}).

## OCR behavior
### `--no-ocr`
Disable the OCR stage.

### `--force-ocr`
Force OCR even if the PDF already has a text layer.

Notes:
- If both `--no-ocr` and `--force-ocr` are set, `--no-ocr` wins.

See: [OCR]({{ "/docs/ocr/" | relative_url }}).

## Debug
### `--max-pages N`
Limit pages processed. Used for debugging performance and false positives.

- `0` means “all pages”.

## Exit codes
- `0`: success
- `2`: CLI usage error (unsupported file type, missing file, invalid option combination)
- `1`: runtime failure (e.g. failed to produce a requested output)
