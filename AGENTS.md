# AGENTS.md (tito-pdf)
Purpose
This file teaches an agent (Claude) how to use the standalone `tito-pdf` helper to convert PDFs to Markdown deterministically (no LLM / no network).
If you are a human user, see `README.md` for the short version.

What this tool does
- Input: a PDF or DOCX file path.

Default outputs (under `--out-dir`, default `.`):
- `md/<id>.retrieve.md` (best-effort Markdown with headings)
- `md/<id>.retrieve.tables.md` (tables only, separated)
- `sessions/run-YYYYMMDD_HHMMSS/<id>.retrieve.tables.audit.json` (table extraction audit)

Integration / contract mode (for orchestration by other tools, e.g. TITO):
- If you set any of these flags:
  - `--raw-text-out PATH`
  - `--tables-out PATH`
  - `--tables-audit-out PATH`
  - `--assets-json PATH`
  then `tito-pdf` writes to the explicit paths and avoids creating `./md/` and `./sessions/` subfolders.
- These flags are not needed for normal human usage; they exist to make the caller control file names/paths deterministically.

Constraints
- Deterministic/offline: no API calls.
- OCR is local-only (via `ocrmypdf` if installed).
- Table extraction is heuristic; expect occasional false positives/negatives.

Setup (one-time)
From the repo root:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
Recommended system deps:
- `qpdf`, `gs` (Ghostscript)
- `tesseract` (for OCR)

Golden path (use this first)
1) Always start with one command that produces both text and tables.
2) Prefer using `--mode` over many flags.

Recommended default invocation (robust):
```bash
./tito-pdf /path/to/doc.pdf --out-dir . --id doc --mode robust
```
Notes:
- `--mode robust` is the default. It runs OCR conservatively and keeps tables strict.
- If you omit `--id`, it will be derived from the filename.

Modes
- `--mode robust` (default)
  - OCR: conservative (`--skip-text`)
  - Tables: strict
- `--mode fast`
  - OCR: off (faster)
  - Tables: strict
- `--mode best`
  - OCR: forced
  - Tables: strict first; if strict finds no tables, retries tables with lenient detection automatically

How to read results
- Text: open `md/<id>.retrieve.md`.
- Tables: open `md/<id>.retrieve.tables.md`.
- Audit: open `sessions/run-.../<id>.retrieve.tables.audit.json`.
  - Use audit to understand which pages had tables and which strategy/tool produced them.

Retry / troubleshooting heuristics (the important part)
You should iterate by re-running `tito-pdf` with a different `--mode` or a small set of flags.
Do NOT invent many parameters; keep retries simple.

A) User says: “Markdown is empty / missing text”
- If the PDF is scanned or text layer is bad:
  - Retry with forced OCR:
    ```bash
    ./tito-pdf /path/to/doc.pdf --out-dir . --id doc --mode best
    ```
- If OCR tools are missing or OCR fails noisily:
  - Retry without OCR:
    ```bash
    ./tito-pdf /path/to/doc.pdf --out-dir . --id doc --mode fast
    ```

B) User says: “No tables detected” (tables file says `(No tables detected.)`)
- First retry:
  - Use `--mode best` (this triggers lenient fallback only when strict finds nothing):
    ```bash
    ./tito-pdf /path/to/doc.pdf --out-dir . --id doc --tables --mode best
    ```
- If runtime is a concern:
  - Limit pages first to confirm there are any tables at all:
    ```bash
    ./tito-pdf /path/to/doc.pdf --out-dir . --id doc --tables --mode best --max-pages 15
    ```

C) User says: “Tables are garbage / false positives”
- Go more strict (reduce recall, reduce noise):
  - Use robust/strict (avoid lenient):
    ```bash
    ./tito-pdf /path/to/doc.pdf --out-dir . --id doc --tables --mode robust
    ```
- If you previously used `--mode best` and got junk, revert to `--mode robust`.

D) User says: “Too slow / huge PDF”
- First do a quick diagnostic run:
  - `--max-pages 10` and/or `--mode fast`:
    ```bash
    ./tito-pdf /path/to/doc.pdf --out-dir . --id doc --mode fast --max-pages 10
    ```
- Then run full once you know it works:
  - remove `--max-pages`.

E) Missing dependencies (imports fail)
- Symptom: import error for `fitz` / `pdfplumber`.
- Fix: activate venv and install requirements:
```bash
source .venv/bin/activate
pip install -r requirements.txt
```

F) OCR fails
- If OCR isn’t necessary, avoid it:
  - `--mode fast` (or `--no-ocr`)
- If OCR is necessary (scanned PDF):
  - ensure `tesseract` + `ocrmypdf` installed, then use `--mode best`.

Operational guidance for Claude
- Don’t paste the full extracted markdown into chat.
- Prefer summarizing and quoting only small snippets with page/table references.
- When debugging tables, use the audit JSON to identify page numbers, then inspect only those table sections.
- Keep retries to a small number of runs (usually 2–3): robust → best (if needed) → robust (if best is noisy).