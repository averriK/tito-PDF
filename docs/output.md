# Output contract

`tito-pdf` has two output styles.

## 1) Explicit output paths (recommended / integration)
If any of these are provided:
- `--md-out PATH`
- `--raw-text-out PATH`
- `--tables-out PATH`
- `--tables-audit-out PATH` (requires `--tables-out`)
- `--assets-json PATH`

…then `tito-pdf` writes exactly to the paths you provide (creating parent directories). It does not create extra output folders.

### Notes
- Writes are atomic (write temp then rename) to avoid leaving empty/misleading files on failure.
- `(No tables detected.)` is a valid successful tables output.

## 2) Convenience mode (no explicit output paths)
If you do not provide any explicit output paths:
- Default: writes `<stem>.md` next to the input file.
- Use `--out-dir DIR` to write into a different directory.
- Use `--tables` or `--all` to also write `<stem>.tables.md`.

## Intermediates
Intermediates (prepared PDFs / OCR outputs) are stored in a temporary working directory and are not kept by default.
