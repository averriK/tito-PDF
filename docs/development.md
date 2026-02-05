---
layout: default
title: Development
permalink: /docs/development/
---

# Development
This page is for contributors working in the repo.

## Repo map
Key files:
- `tito-pdf`: main CLI (single Python script)
- `requirements.txt`: Python dependencies
- `install/`
  - `install.sh`, `uninstall.sh`: macOS/Linux installer
  - `install.ps1`, `uninstall.ps1`: Windows installer
  - `manifest.json`: install paths
- `tests/smoke/tito_pdf_smoke.sh`: deterministic smoke test
- `docs/`: GitHub Pages documentation

## Testing policy (non-negotiable)
Always validate the **installed** `tito-pdf` binary.

After any code change:

```bash
sudo ./install/install.sh
command -v tito-pdf
tito-pdf --help
./tests/smoke/tito_pdf_smoke.sh
```

Why:
- we want to test the *real* user-facing binary (`/usr/local/bin/tito-pdf` by default)
- it prevents “works in repo, fails when installed” regressions

## Smoke test notes
`tests/smoke/tito_pdf_smoke.sh`:
- runs `tito-pdf` from PATH
- creates a tiny PDF (selectable text)
- creates a tiny DOCX via an ephemeral venv (installs `python-docx`)

If the smoke test is slow:
- it may be spending time in pip installs for the ephemeral venv.

## Versioning
The CLI version is currently defined in the `tito-pdf` script (`__version__`).

If you bump behavior or flags:
- bump `__version__`
- update docs (`docs/` + `README.md`)
- re-run smoke tests against the installed binary

## Docs (GitHub Pages)
This repo is published via GitHub Pages from the `/docs` folder.

Docs rules:
- Every doc page must have YAML front matter (`title`, `permalink`).
- Prefer permalink links (`/docs/install/`) + `relative_url` in Liquid.
- Keep docs consistent with installed `tito-pdf --help` and behavior.

Start here: [Docs index]({{ "/docs/" | relative_url }}).

## Line endings (important)
Do not introduce CRLF line endings in `*.sh` scripts (breaks macOS/Linux).
