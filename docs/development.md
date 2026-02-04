# Development

## Repo map
- `tito-pdf`: main CLI (single Python script)
- `install/`: installers for macOS/Linux + Windows
- `tests/smoke/tito_pdf_smoke.sh`: deterministic smoke test

## Testing policy (important)
Always validate the **installed** `tito-pdf` binary.

After any code change:

```bash
sudo ./install/install.sh
command -v tito-pdf
tito-pdf --help
./tests/smoke/tito_pdf_smoke.sh
```

## Line endings
Do not introduce CRLF line endings in `*.sh` scripts.

## Docs
GitHub Pages docs live under `docs/`. Keep `README.md` and `docs/` consistent with the installed `tito-pdf --help`.
