---
layout: default
title: tito-pdf — Documentation
permalink: /
---

# tito-pdf
`tito-pdf` is a standalone, deterministic, local-only converter:

- Inputs: `.pdf`, `.docx`
- Outputs: Markdown (`.md`) + optional tables Markdown (`.tables.md`)
- Offline: no network calls, no LLMs
- No hidden run/job/session semantics

If you are looking for **TITO** (the orchestrator) semantics, this repo is **not** that tool.

## Quickstart (recommended)
Write primary Markdown to an explicit path:

```bash
tito-pdf input.pdf --md-out out/input.md
```

Tables + audit JSON + assets JSON (typical integration run):

```bash
tito-pdf input.pdf \
  --mode best \
  --md-out out/input.md \
  --tables-out out/input.tables.md \
  --tables-audit-out out/input.tables.audit.json \
  --assets-json out/input.assets.json
```

## Convenience mode (no explicit outputs)
If you do not provide any explicit output paths, `tito-pdf` writes next to the input file by default:

```bash
tito-pdf /path/to/input.pdf
# => /path/to/input.md
```

Write into a directory:

```bash
tito-pdf input.pdf --out-dir out
```

Tables:

```bash
tito-pdf input.pdf --tables --out-dir out
# => out/input.tables.md
```

Text + tables:

```bash
tito-pdf input.pdf --all --out-dir out
# => out/input.md + out/input.tables.md
```

## Two output styles (contract)
There are exactly two output styles:

1) Explicit output mode (recommended / integration)
If you set any of:
- `--md-out PATH`
- `--raw-text-out PATH`
- `--tables-out PATH`
- `--tables-audit-out PATH` (requires `--tables-out`)
- `--assets-json PATH`

…then `tito-pdf` writes **only** to the paths you requested (creating parent directories and using atomic writes). It does not create extra output folders.

2) Convenience mode (human)
If no explicit paths are set:
- Default: writes `<stem>.md` next to the input.
- `--out-dir DIR` writes into `DIR`.
- `--tables` / `--all` also writes `<stem>.tables.md`.

## Documentation
Start here: [Docs index]({{ "/docs/" | relative_url }}).

Core references:
- Install: [Install]({{ "/docs/install/" | relative_url }})
- Usage: [Usage]({{ "/docs/usage/" | relative_url }})
- CLI flags (by parameter): [CLI]({{ "/docs/cli/" | relative_url }})
- Output contract: [Output contract]({{ "/docs/output/" | relative_url }})
- Design rationale (why multiple tools): [Rationale]({{ "/docs/rationale/" | relative_url }})
- Implementation details (thresholds + heuristics): [Implementation]({{ "/docs/implementation/" | relative_url }})
- Pipeline (how it works): [Pipeline]({{ "/docs/pipeline/" | relative_url }})
- OCR: [OCR]({{ "/docs/ocr/" | relative_url }})
- Tables: [Tables]({{ "/docs/tables/" | relative_url }})
- Assets JSON: [Assets JSON]({{ "/docs/assets-json/" | relative_url }})
- Troubleshooting: [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }})
- Development/testing: [Development]({{ "/docs/development/" | relative_url }})
- FAQ: [FAQ]({{ "/docs/faq/" | relative_url }})
- Español: [Guía rápida]({{ "/docs/es/" | relative_url }})

## tito vs tito-pdf (common confusion)
- `tito` is an orchestrator with run/job/session semantics.
- `tito-pdf` is a single-document converter that writes deterministic files.

If `tito --help` shows env-var-looking defaults, that is **not** this repo.

Sanity checks:

```bash
command -v tito
command -v tito-pdf
tito-pdf --help
```
