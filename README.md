# tito-pdf
Convert `.pdf` / `.docx` documents to Markdown (and optionally extract tables).

For maintainers and agents, read `AGENTS.md`.

## Install
### Option A (recommended): installer
#### macOS/Linux
System-wide install (writes to `/usr/local/bin` and `/usr/local/libexec/tito-pdf`):

```bash
sudo ./install/install.sh
```

Uninstall:

```bash
sudo ./install/uninstall.sh
```

#### Windows (PowerShell)
User install (writes to `%LOCALAPPDATA%\\Programs\\_runtime\\tito-pdf` and creates shims under `%LOCALAPPDATA%\\Programs`).

By default, the installer will also attempt a best-effort install of recommended system dependencies (`qpdf`, `tesseract`) via `winget`/`choco` when available. To skip that step:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\install\\install.ps1 -InstallSystemDeps:$false
```

Default install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\install\\install.ps1
```

Uninstall:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install\uninstall.ps1
```

### System dependency (required)
Install `qpdf` (required for PDF conversion):

```bash
brew install qpdf
```

Optional (only if you use OCR):

```bash
brew install tesseract
```

## Run
CLI flags/parameters are documented in `tito-pdf --help` (kept intentionally options-focused). This README covers behavior and examples.

Recommended (explicit primary output):

```bash
tito-pdf /path/to/doc.pdf --md-out /tmp/doc.md
```

Convenience mode (TITO-aligned folder structure):

```bash
tito-pdf /path/to/doc.pdf --id myrun          # writes md/myrun.retrieve.md
tito-pdf /path/to/doc.pdf --id myrun --tables # writes md/myrun.retrieve.md + md/myrun.retrieve.tables.md
tito-pdf /path/to/doc.pdf --id myrun --all    # same as above
```

With `--out-dir`:

```bash
tito-pdf /path/to/doc.pdf --id myrun --out-dir out   # writes out/md/myrun.retrieve.md
```

Preserve intermediate files for debugging:

```bash
tito-pdf /path/to/doc.pdf --id myrun --keep-sessions  # creates sessions/run-YYYYMMDD_HHMMSS/
```

DOCX is also supported:

```bash
tito-pdf /path/to/doc.docx --md-out /tmp/doc.md
```

Modes:
```bash
tito-pdf /path/to/doc.pdf --mode robust   # default
tito-pdf /path/to/doc.pdf --mode fast     # no OCR
tito-pdf /path/to/doc.pdf --mode best     # force OCR + tables lenient fallback
```

Explicit output paths (integration mode):
- If you set any explicit output path (`--md-out`, `--raw-text-out`, `--tables-out`, `--tables-audit-out`, `--assets-json`), `tito-pdf` writes to those paths and does not create extra output folders.
- `--tables-audit-out` requires `--tables-out`.

Example:

```bash
tito-pdf /path/to/doc.pdf \
  --mode fast \
  --md-out out/doc.md \
  --raw-text-out out/doc.raw.txt \
  --tables-out out/doc.tables.md \
  --tables-audit-out out/doc.tables.audit.json \
  --assets-json out/doc.assets.json
```

## Documentation (GitHub Pages)
This repo publishes documentation via GitHub Pages from the `docs/` folder.

- Site home: https://averrik.github.io/tito-PDF/
- Docs index: https://averrik.github.io/tito-PDF/docs/

Core pages:
- Install: https://averrik.github.io/tito-PDF/docs/install/
- Usage: https://averrik.github.io/tito-PDF/docs/usage/
- CLI reference (every parameter): https://averrik.github.io/tito-PDF/docs/cli/
- Output contract: https://averrik.github.io/tito-PDF/docs/output/
- Pipeline (how it works): https://averrik.github.io/tito-PDF/docs/pipeline/
- OCR: https://averrik.github.io/tito-PDF/docs/ocr/
- Tables: https://averrik.github.io/tito-PDF/docs/tables/
- Troubleshooting: https://averrik.github.io/tito-PDF/docs/troubleshooting/

Publishing settings (GitHub):
1. Repo Settings → Pages
2. Build and deployment: Deploy from a branch
3. Branch: `main` / Folder: `/docs`

## Agent usage
See `AGENTS.md` for the retry heuristics and troubleshooting playbook.
