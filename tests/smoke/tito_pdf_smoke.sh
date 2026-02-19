#!/bin/bash
# Deterministic smoke test for *installed* tito-pdf (PDF + DOCX).
#
# Policy: validate the PATH-installed `tito-pdf` binary, not the repo script.
# The ephemeral venv below is only used to generate a tiny DOCX input (python-docx).
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 1
fi

if ! command -v tito-pdf >/dev/null 2>&1; then
  echo "ERROR: tito-pdf not found on PATH." >&2
  echo "Install it first (system-wide):" >&2
  echo "  sudo $ROOT_DIR/install/install.sh" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t tito_pdf_smoke)"
cleanup() {
  rm -rf "$TMP_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

OUT_DIR="$TMP_DIR/out"
mkdir -p "$OUT_DIR"
# Create a tiny, valid PDF with selectable text.
PDF_PATH="$TMP_DIR/hello.pdf"
export PDF_PATH
python3 - <<'PY'
import os
import pathlib


def write_minimal_pdf(path: str) -> None:
    # Minimal PDF with one page and one text draw (Helvetica).
    stream = "BT\n/F1 24 Tf\n72 120 Td\n(Hello PDF) Tj\nET"
    stream_len = len(stream.encode("utf-8"))

    objects = []
    objects.append("<< /Type /Catalog /Pages 2 0 R >>")
    objects.append("<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
    objects.append(
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R "
        "/Resources << /Font << /F1 5 0 R >> >> >>"
    )
    objects.append(f"<< /Length {stream_len} >>\nstream\n{stream}\nendstream")
    objects.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    out = ["%PDF-1.4\n"]
    offsets = [0]
    pos = len(out[0].encode("ascii"))

    for i, obj in enumerate(objects, start=1):
        offsets.append(pos)
        s = f"{i} 0 obj\n{obj}\nendobj\n"
        out.append(s)
        pos += len(s.encode("utf-8"))

    xref_pos = pos
    n = len(objects) + 1

    xref = [f"xref\n0 {n}\n", "0000000000 65535 f \n"]
    for off in offsets[1:]:
        xref.append(f"{off:010d} 00000 n \n")

    out.append("".join(xref))
    out.append(f"trailer\n<< /Size {n} /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n")

    pathlib.Path(path).write_bytes("".join(out).encode("utf-8"))


write_minimal_pdf(os.environ["PDF_PATH"])
PY
# Ensure the installed CLI contract is visible.
HELP_OUTPUT="$(tito-pdf --help 2>&1)"

# --id and --keep-sessions must be visible (TITO-aligned convenience mode).
if ! printf '%s\n' "$HELP_OUTPUT" | grep -q -- "--id ID"; then
  echo "ERROR: tito-pdf --help should show '--id ID'" >&2
  exit 1
fi
if ! printf '%s\n' "$HELP_OUTPUT" | grep -q -- "--keep-sessions"; then
  echo "ERROR: tito-pdf --help should show '--keep-sessions'" >&2
  exit 1
fi

# Help should be options-focused (no narrative blocks).
if printf '%s\n' "$HELP_OUTPUT" | grep -q -- "Defaults are built-in"; then
  echo "ERROR: tito-pdf --help should not include narrative text about env vars/defaults" >&2
  exit 1
fi
if printf '%s\n' "$HELP_OUTPUT" | grep -q -- "Recommended (standalone) usage"; then
  echo "ERROR: tito-pdf --help should not include long examples/epilog" >&2
  exit 1
fi

# Metavars should be clear (PATH/DIR/N), not confusing placeholders.
if ! printf '%s\n' "$HELP_OUTPUT" | grep -q -- "--md-out PATH"; then
  echo "ERROR: tito-pdf --help should show '--md-out PATH'" >&2
  exit 1
fi
if ! printf '%s\n' "$HELP_OUTPUT" | grep -q -- "--tables-audit-out PATH"; then
  echo "ERROR: tito-pdf --help should show '--tables-audit-out PATH'" >&2
  exit 1
fi

# GNU-style: version flag.
VERSION_OUTPUT="$(tito-pdf --version 2>&1)"
if ! printf '%s\n' "$VERSION_OUTPUT" | grep -qE '^tito-pdf\s+'; then
  echo "ERROR: tito-pdf --version should print a version header" >&2
  exit 1
fi

# Run PDF extraction with explicit output paths (fast = no OCR).
tito-pdf "$PDF_PATH" \
  --mode fast \
  --md-out "$OUT_DIR/pdf.md" \
  --raw-text-out "$OUT_DIR/pdf.raw.txt" \
  --tables-out "$OUT_DIR/pdf.tables.md" \
  --tables-audit-out "$OUT_DIR/pdf.tables.audit.json" \
  --assets-json "$OUT_DIR/pdf.assets.json" \
  >/dev/null

grep -q "Hello PDF" "$OUT_DIR/pdf.md"
grep -q "Hello PDF" "$OUT_DIR/pdf.raw.txt"

# Convenience mode: deliverables go to <out-dir>/md/<id>.retrieve.md
CONV_DIR="$OUT_DIR/convenience"
mkdir -p "$CONV_DIR"
tito-pdf "$PDF_PATH" --mode fast --out-dir "$CONV_DIR" --id smoke_test >/dev/null

test -s "$CONV_DIR/md/smoke_test.retrieve.md"
grep -q "Hello PDF" "$CONV_DIR/md/smoke_test.retrieve.md"

# Convenience mode with --tables: both outputs go to md/
tito-pdf "$PDF_PATH" --mode fast --out-dir "$CONV_DIR" --id smoke_all --all >/dev/null
test -s "$CONV_DIR/md/smoke_all.retrieve.md"
test -s "$CONV_DIR/md/smoke_all.retrieve.tables.md"

# Create a tiny DOCX (needs python-docx).
VENV_DIR="$TMP_DIR/venv"
python3 -m venv "$VENV_DIR"

echo "+ Installing python-docx into ephemeral venv..."
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
"$VENV_DIR/bin/pip" install python-docx

DOCX_PATH="$TMP_DIR/hello.docx"
export DOCX_PATH
"$VENV_DIR/bin/python" - <<'PY'
import os
from docx import Document

doc = Document()
doc.add_heading("Hello DOCX", level=1)
doc.add_paragraph("This is a paragraph.")

table = doc.add_table(rows=2, cols=2)
table.cell(0, 0).text = "A"
table.cell(0, 1).text = "B"
table.cell(1, 0).text = "1"
table.cell(1, 1).text = "2"

doc.save(os.environ["DOCX_PATH"])
PY

# Run DOCX extraction with explicit output paths.
tito-pdf "$DOCX_PATH" \
  --mode fast \
  --md-out "$OUT_DIR/docx.md" \
  --raw-text-out "$OUT_DIR/docx.raw.txt" \
  --tables-out "$OUT_DIR/docx.tables.md" \
  --tables-audit-out "$OUT_DIR/docx.tables.audit.json" \
  --assets-json "$OUT_DIR/docx.assets.json" \
  >/dev/null

grep -q "Hello DOCX" "$OUT_DIR/docx.md"
grep -q "Hello DOCX" "$OUT_DIR/docx.raw.txt"
grep -Fq "| A | B |" "$OUT_DIR/docx.tables.md"

test -s "$OUT_DIR/pdf.assets.json"
test -s "$OUT_DIR/docx.assets.json"

# Validate a few required assets-json keys.
export OUT_DIR
python3 - <<'PY'
import json
import os
import pathlib

out_dir = pathlib.Path(os.environ["OUT_DIR"])
for p in [
    out_dir / "pdf.assets.json",
    out_dir / "docx.assets.json",
]:
    data = json.loads(p.read_text(encoding="utf-8"))
    assert data.get("schema_version") == 1
    assert data.get("tool") == "tito-pdf"
    assert data.get("started_at_utc")
    assert data.get("finished_at_utc")
    assert isinstance(data.get("duration_ms"), int)
    assert isinstance(data.get("metrics", {}), dict)

print("OK")
PY
