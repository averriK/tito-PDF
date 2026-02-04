# Install

## macOS/Linux (recommended)
System-wide install (writes to `/usr/local/bin` and `/usr/local/libexec/tito-pdf`):

```bash
sudo ./install/install.sh
```

Uninstall:

```bash
sudo ./install/uninstall.sh
```

## Windows (PowerShell)
User install (writes under `%LOCALAPPDATA%\\Programs`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\install\\install.ps1
```

Uninstall:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\install\\uninstall.ps1
```

## System dependencies (recommended)
`tito-pdf` works without these, but quality/performance improve when available:
- `qpdf`
- Ghostscript (`gs` / `gswin64c`)
- `tesseract` (for OCR)

See `tito-pdf --help` for runtime flags and `troubleshooting.md` for common issues.
