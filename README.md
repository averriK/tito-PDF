# tito-pdf
Standalone, deterministic PDF → Markdown helper inspired by `tito retrieve`, but **without** LLM/claude-flow.

If you are Claude (an agent), read `AGENTS.md`.

## Install
Create a venv (or use `uv`) and install deps:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

System deps (recommended):
- `qpdf`, `gs` (Ghostscript)
- `tesseract` (for OCR)

## Run
One command (text + tables) — default mode is `robust`:

```bash
./tito-pdf /path/to/doc.pdf
```

Modes:
```bash
./tito-pdf /path/to/doc.pdf --mode robust   # default
./tito-pdf /path/to/doc.pdf --mode fast     # no OCR
./tito-pdf /path/to/doc.pdf --mode best     # force OCR + tables lenient fallback
```

Outputs (by default under the current working directory):
- `md/<id>.retrieve.md`
- `md/<id>.retrieve.tables.md`
- `sessions/run-.../` (intermediates + audit JSON)

Integration mode:
- If you set explicit output paths (`--raw-text-out`, `--tables-out`, `--tables-audit-out`, `--assets-json`), `tito-pdf` writes to those paths and avoids creating `md/` and `sessions/` subfolders.

## Agent usage
See `AGENTS.md` for the retry heuristics and troubleshooting playbook.
