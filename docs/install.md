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

## Recommended system dependencies (and why they exist)
`tito-pdf` will run without these tools, but behavior changes when they are missing.

- Without `qpdf`, PDF normalization/decryption is skipped.
- Without Ghostscript, image stripping is skipped.
- Without `tesseract`, OCR may fail or be unavailable (scanned PDFs will often produce little/no text).

### `qpdf`
Used in `prepare_pdf()` to normalize/decrypt PDFs (`qpdf --decrypt`). This improves robustness for:
- PDFs that are technically “encrypted” or partially protected.
- PDFs with structural oddities that can break downstream parsers.

macOS install:

```bash
brew install qpdf
```

### Ghostscript (`gs` / `gswin64c`)
Used in `prepare_pdf()` to optionally strip raster images (`-dFILTERIMAGE`) **when OCR is disabled**.

Why it matters:
- Smaller PDFs can be faster for layout/text extraction.
- It can reduce file size and speed up parsing when images are not needed.

Important limitation:
- Stripping images can remove content that only exists as images.
- `tito-pdf` only strips images when OCR is disabled.

macOS install:

```bash
brew install ghostscript
```

On Windows the command is often `gswin64c` (or `gswin32c`).

### `tesseract`
Required for OCR. `ocrmypdf` uses Tesseract under the hood.

macOS install:

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
