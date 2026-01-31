#!/bin/bash
# Deterministic smoke test for tito-pdf (PDF + DOCX).
#
# Runs in an ephemeral venv to ensure Python deps are available.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t tito_pdf_smoke)"
cleanup() {
  rm -rf "$TMP_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

VENV_DIR="$TMP_DIR/venv"
python3 -m venv "$VENV_DIR"

# Install deps (quiet-ish but still shows pip progress on errors)
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null
"$VENV_DIR/bin/pip" install -r "$ROOT_DIR/requirements.txt" >/dev/null

OUT_DIR="$TMP_DIR/out"
mkdir -p "$OUT_DIR"
# Create a tiny, valid PDF with selectable text.
PDF_PATH="$TMP_DIR/hello.pdf"
export PDF_PATH
"$VENV_DIR/bin/python" - <<'PY'
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
# Run PDF extraction in contract mode.
"$VENV_DIR/bin/python" "$ROOT_DIR/tito-pdf" "$PDF_PATH" \
  --mode fast \
  --raw-text-out "$OUT_DIR/pdf.raw.txt" \
  --tables-out "$OUT_DIR/pdf.tables.md" \
  --tables-audit-out "$OUT_DIR/pdf.tables.audit.json" \
  --assets-json "$OUT_DIR/pdf.assets.json" \
  >/dev/null

grep -q "Hello PDF" "$OUT_DIR/pdf.raw.txt"

# Create a tiny DOCX.
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

# Run DOCX extraction in contract mode.
"$VENV_DIR/bin/python" "$ROOT_DIR/tito-pdf" "$DOCX_PATH" \
  --mode fast \
  --raw-text-out "$OUT_DIR/docx.raw.txt" \
  --tables-out "$OUT_DIR/docx.tables.md" \
  --tables-audit-out "$OUT_DIR/docx.tables.audit.json" \
  --assets-json "$OUT_DIR/docx.assets.json" \
  >/dev/null

grep -q "Hello DOCX" "$OUT_DIR/docx.raw.txt"
grep -Fq "| A | B |" "$OUT_DIR/docx.tables.md"

test -s "$OUT_DIR/pdf.assets.json"
test -s "$OUT_DIR/docx.assets.json"

# Validate a few required run-report keys.
export OUT_DIR
"$VENV_DIR/bin/python" - <<'PY'
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
