# AGENTS.md (tito-pdf)

## Purpose (what this file is / is not)
This file is **stable orientation** for humans and agents working in this repo.

It **is**:
- A map of the repo and its concepts.
- Non‑negotiables (“no‑regress” contracts).
- Fast recovery + navigation jump points.

It is **not**:
- A run log or day-by-day status. For operational status + exact revalidation commands, see `START_HERE.txt`.

## Recovery order (if you lost all context)
1) `START_HERE.txt` (operational source of truth, current status, exact commands).
2) `MASTER_PLAN.txt` (local snapshot of the canonical Warp plan).
3) `README.md` (human quickstart) and `SKILL_TITO_PDF.md` (Spanish skill doc).
4) Use the “Jump points” section below to navigate code quickly.

## Product summary
`tito-pdf` is a **deterministic, local-only** PDF/DOCX → Markdown (+ tables) helper inspired by TITO’s `retrieve` naming, but **without** LLM / claude-flow / network.

### User-facing vs internal
User-facing (contract):
- CLI (installed): `tito-pdf <input.pdf|input.docx> [flags]`
- CLI (repo script): `./tito-pdf <input.pdf|input.docx> [flags]`
- Installers: `install/install.sh`, `install/install.ps1`

Internal stages (implementation details):
- PDF prep: `prepare_pdf()`
- OCR: `ocr_pdf()`
- PDF text: `extract_lines_layout()` → `drop_repeated_headers_footers()` → `lines_to_markdown()` / `lines_to_text()`
- PDF tables: `extract_tables()` (PyMuPDF primary; optional Camelot; pdfplumber fallback)
- DOCX: `extract_docx_markdown()` / `extract_docx_text()` / `extract_docx_tables()`

## IMPORTANT: common confusion (tito vs tito-pdf)
If you run **`tito --help`** and it shows confusing defaults that look like environment variables, you are looking at **a different tool** (the TITO orchestrator), not this repo.

This repo guarantees the behavior of:
- `./tito-pdf --help` (repo script)
- `tito-pdf --help` (only after installing *this* repo)

Sanity checks:
- `command -v tito`
- `command -v tito-pdf`
- `tito-pdf --help`

Docs in this repo should **not** claim users must set environment variables to run `tito-pdf`.

## Core concepts (minimum)
### Inputs
- Supported: `.pdf`, `.docx`

### Outputs
There are two output styles:

1) Explicit output paths (recommended / integration)
If any of these are provided:
- `--md-out PATH`
- `--raw-text-out PATH`
- `--tables-out PATH`
- `--tables-audit-out PATH` (requires `--tables-out`)
- `--assets-json PATH`

…then `tito-pdf` writes exactly to those paths and does not create extra output folders.

2) Convenience mode (no explicit output paths)
- Default: writes `<stem>.md` next to the input file.
- Use `--out-dir DIR` to write into a different directory.
- Use `--tables` or `--all` to also write `<stem>.tables.md`.

### Modes and knobs
Prefer `--mode` over many flags:
- `--mode robust` (default): OCR conservative + tables strict
- `--mode fast`: disables OCR (good for quick runs / good text layer)
- `--mode best`: forces OCR and enables tables lenient *fallback* when strict finds no tables

Overrides:
- `--no-ocr` disables OCR even in `best`
- `--force-ocr` forces OCR even if PDF already has text
- `--tables-lenient` increases table recall (more false positives)

## Naming conventions (and where they’re defined)
- Output stem (convenience mode): derived from input filename stem (`Path.stem`).
- Convenience filenames:
  - Text Markdown: `<stem>.md`
  - Tables Markdown: `<stem>.tables.md`
- Explicit output paths: exactly as provided via flags.
- Legacy: `--id` is accepted (hidden) only for transition, but is deprecated and prints a warning when used.

Primary doc sources:
- User-level: `README.md`
- Skill-level (Spanish): `SKILL_TITO_PDF.md`
- Source-of-truth: `tito-pdf` (CLI + behavior)

## Non-negotiables (no-regress policies)
- Offline/deterministic: no API calls, no network dependencies.
- Output naming/paths must remain stable (see “Outputs” above).
- When explicit output paths are used, `tito-pdf` must write only to the requested paths (no extra folders).
- Convenience mode must not create `md/` or `sessions/` folders.
- Assets JSON contract must remain compatible:
  - `schema_version == 1`
  - `tool == "tito-pdf"`
  - includes `started_at_utc`, `finished_at_utc`, `duration_ms`, and a `metrics` object.
- `--help` must describe **real** behavior/defaults and must not invent env-var defaults.
- Install launcher must forward arguments at runtime (`"$@"`), not expand them at install time.
- Do not introduce CRLF line endings in `*.sh` scripts (breaks macOS/Linux).

## Repo map (where is what)
- `tito-pdf`: main CLI script (argparse + pipeline)
- `requirements.txt`: Python deps (PyMuPDF, pdfplumber, ocrmypdf, python-docx, …)
- `install/`
  - `install.sh`, `uninstall.sh`: macOS/Linux installer
  - `install.ps1`, `uninstall.ps1`: Windows installer
  - `manifest.json`: install paths
  - `validate_manifest.sh`: quick manifest validator (needs `jq`)
- `tests/smoke/tito_pdf_smoke.sh`: deterministic end-to-end smoke test
- `md/`, `sessions/`: legacy/generated outputs from older versions (not source; do not commit)

## Jump points (fast navigation)
Files:
- `tito-pdf`
- `tests/smoke/tito_pdf_smoke.sh`
- `install/install.sh`
- `install/manifest.json`
- `README.md`, `SKILL_TITO_PDF.md`

Grep targets:
- `md_out`
- `explicit_output_mode`
- `schema_version`
- `assets_json`
- `tables_auto_fallback`
- `tables_lenient`
- `extract_tables(`
- `prepare_pdf(`
- `ocr_pdf(`
- `extract_lines_layout(`
- `drop_repeated_headers_footers(`
- `lines_to_markdown(`

## Stress-proof recovery drill (commands)
Run from repo root:
```bash
ls -la
sudo ./install/install.sh
command -v tito-pdf
tito-pdf --help
./tests/smoke/tito_pdf_smoke.sh
```

## Troubleshooting / retry heuristics (keep it simple)
Preferred retry order is usually:
- `--mode robust` → `--mode best` (if missing text/tables) → back to `--mode robust` (if best gets noisy).

Common cases:
- Missing text: try `--mode best` (forces OCR)
- OCR fails/noisy: try `--mode fast` or `--no-ocr`
- No tables detected: try `--mode best` (enables lenient fallback only if strict finds none)
- Too slow/huge PDF: try `--mode fast --max-pages 10` as a quick diagnostic

## Documentation update rules
- `tito-pdf --help` (installed) is the CLI contract; keep help strings accurate.
- After code changes, reinstall before validating:
  - `sudo ./install/install.sh`
- If you change flags/default behavior, update all of:
  - `README.md`
  - `SKILL_TITO_PDF.md`
  - this file (`AGENTS.md`)
- Avoid docs that imply users must set env vars to run `tito-pdf`.
- Keep operational status out of this file; put it in `START_HERE.txt`.

## Handoff checklist (before closing a session)
- Update `START_HERE.txt` status (DONE/VERIFIED/PENDING) and keep dates concrete.
- Ensure `MASTER_PLAN.txt` matches the canonical Warp plan.
- Run the cheap checks from the recovery drill.
- Confirm `git status` is clean (or document intentional changes in `START_HERE.txt`).
