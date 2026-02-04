# Assets JSON

`tito-pdf` can write an assets/metrics JSON file via:

```bash
tito-pdf input.pdf --assets-json out/assets.json --md-out out/input.md
```

## Contract (stable keys)
- `schema_version` = `1`
- `tool` = `"tito-pdf"`
- `started_at_utc`, `finished_at_utc`
- `duration_ms`
- `mode`, `input_kind`, `input_path`, `input_size_bytes`
- `timings_ms` (stage durations)
- `metrics` (at minimum: `raw_text_bytes`, `raw_text_lines`, `tables_count`)

## Optional sections
- `outputs`: paths that were written
- `toolchain`: best-effort versions/paths for system tools and Python packages
