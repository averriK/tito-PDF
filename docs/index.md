---
title: tito-pdf
---

# tito-pdf
`tito-pdf` is a standalone, deterministic, local-only converter.

- Inputs: `.pdf`, `.docx`
- Outputs: Markdown (`.md`) + optional tables Markdown (`.tables.md`)

## Quickstart
Recommended (explicit primary output):

```bash
tito-pdf input.pdf --md-out out/input.md
```

Convenience mode (no explicit output paths):

```bash
tito-pdf input.pdf            # writes input.md next to the input
tito-pdf input.pdf --out-dir out
```

Tables:

```bash
tito-pdf input.pdf --tables --out-dir out
```

## Documentation
- Install: [install](install.md)
- CLI flags: [cli](cli.md)
- Output contract: [output](output.md)
- Assets JSON: [assets-json](assets-json.md)
- Troubleshooting: [troubleshooting](troubleshooting.md)
- Development/testing: [development](development.md)
- Español: [es](es.md)

## Principles
- Offline/local-only: no API calls.
- Deterministic pipeline (toolchain/version dependent).
- Explicit output paths are authoritative (writes only to the requested paths).
