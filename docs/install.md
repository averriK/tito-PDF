---
layout: default
title: Install
permalink: /docs/install/
---

# Install
`tito-pdf` is a local CLI (no network, no LLM) that runs as a single Python script with a small toolchain.

The recommended installation method is the repo installer, which creates an isolated Python venv and installs a launcher (`tito-pdf`) into your PATH.

## macOS / Linux (system-wide installer)
From the repo root:

```bash
sudo ./install/install.sh
```

What the installer does (high level):
- Reads `install/manifest.json` to choose install locations.
- Installs a launcher into the manifest `BIN_DIR` (default: `/usr/local/bin/tito-pdf`).
- Copies runtime files into the manifest `LIBEXEC_DIR` (default: `/usr/local/libexec/tito-pdf`).
- Creates a dedicated venv under `LIBEXEC_DIR/.venv` and installs `requirements.txt` into it.
- Writes `BUILD_INFO` and `INSTALL_MANIFEST` so upgrades/uninstall can remove the correct paths.

Uninstall:

```bash
sudo ./install/uninstall.sh
```

Upgrade:
Run `sudo ./install/install.sh` again. The installer removes the prior installation using the recorded manifest.

## Windows (PowerShell installer)
From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install\install.ps1
```

Defaults:
- Install root: `%LOCALAPPDATA%\Programs\_runtime\tito-pdf`
- User bin dir (shims): `%LOCALAPPDATA%\Programs`

Uninstall:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install\uninstall.ps1
```

Notes:
- The installer can (best effort) install system dependencies via `winget`/`choco`.
- Open a **new terminal** after installation so PATH changes take effect.

## Required system dependency
### `qpdf`
`qpdf` is required for PDF conversion.

- `tito-pdf` uses it in `prepare_pdf()` to normalize/decrypt PDFs (`qpdf --decrypt`).

Install on macOS:

```bash
brew install qpdf
```

## OCR dependency (only if you use OCR)
### `tesseract`
OCR requires `tesseract`.

Install on macOS:

```bash
brew install tesseract
```

## Verify the installed CLI
Always verify the installed binary (not the repo script):

```bash
command -v tito-pdf
tito-pdf --version
tito-pdf --help
```

For contributors: see [Development]({{ "/docs/development/" | relative_url }}) for the “installed-binary-only” validation policy.
