---
layout: default
title: FAQ
permalink: /docs/faq/
---

# FAQ

## Why does `--out-dir` sometimes do nothing?
Because you are in **explicit output mode**.

If you set any explicit output path (like `--md-out` or `--tables-out`), `tito-pdf` writes only to those paths and ignores `--out-dir`.

See: [Output contract]({{ "/docs/output/" | relative_url }}).

## Why does `--tables-audit-out` require `--tables-out`?
Because the audit is defined as a companion to the Markdown tables output.

It is a contract rule:
- `--tables-audit-out PATH` is only valid together with `--tables-out PATH`.

## Why can’t I request only `--assets-json`?
`--assets-json` is treated as a companion output. In explicit output mode you must also request at least one “content” output:
- `--md-out` and/or
- `--raw-text-out` and/or
- `--tables-out`

Rationale:
- assets JSON is meaningful when paired with the produced content.

## Why do outputs differ across machines?
`tito-pdf` is deterministic (no network, no randomness), but results can still differ because:
- PDF parsing depends on library versions (PyMuPDF, pdfplumber, etc.)
- OCR depends on `ocrmypdf` + `tesseract` versions and language data

If you need forensic metadata, enable `--assets-json`.

## Why is OCR enabled in `robust` mode?
Because robust mode is trying to maximize extraction quality for unknown PDFs.

If you want speed and your PDFs have a good text layer, use:

```bash
tito-pdf input.pdf --mode fast --md-out out/input.md
```

## Why are there no `sessions/` folders?
This is an explicit no-regress contract.

`tito-pdf` runs in a temporary working directory and deletes intermediates by default.

## Where should I report bugs or request features?
Use GitHub issues:
- {{ site.issues_url }}
