#!/bin/bash
# Install tito-pdf using install/manifest.json-defined installation paths.
#
# Usage:
#   ./install/install.sh
#
# Notes:
# - This script installs the tito-pdf launcher into /usr/local/bin (or the
#   manifest-defined BIN_DIR) and installs runtime assets into /usr/local/libexec/tito-pdf.
# - It creates a dedicated Python venv under libexec and installs requirements there.
# - System deps:
#   - qpdf is required for PDF conversion
#   - tesseract is recommended for OCR
#   If deps are missing and Homebrew is available (and not running as root), this
#   script may attempt a best-effort install.
#
# IMPORTANT: do not run sudo inside this script. If you want a system-wide install,
# run this script with sudo.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: install/manifest.json not found at $MANIFEST" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to parse install/manifest.json" >&2
  echo "Install jq (e.g. 'brew install jq') and re-run ./install/install.sh" >&2
  exit 1
fi

# Validate expected source files
if [ ! -f "$ROOT_DIR/tito-pdf" ]; then
  echo "ERROR: tito-pdf script not found in repo root ($ROOT_DIR/tito-pdf)" >&2
  exit 1
fi

if [ ! -f "$ROOT_DIR/requirements.txt" ]; then
  echo "ERROR: requirements.txt not found in repo root ($ROOT_DIR/requirements.txt)" >&2
  exit 1
fi

BIN_DIR="$(jq -r '.binaries[0].install_dir' "$MANIFEST")"
LIBEXEC_DIR="$(jq -r '.libexec.install_dir' "$MANIFEST")"
INSTALL_MANIFEST="$LIBEXEC_DIR/INSTALL_MANIFEST"
VENV_DIR="$LIBEXEC_DIR/.venv"

remove_file() {
  local p="$1"
  if [ -z "$p" ] || [ "$p" = "/" ]; then
    return 0
  fi
  if [ -e "$p" ] || [ -L "$p" ]; then
    rm -f "$p" || {
      echo "ERROR: Could not remove $p (permission denied?)." >&2
      echo "If you want a system-wide installation, run this script with sudo:" >&2
      echo "  sudo ./install/install.sh" >&2
      exit 1
    }
  fi
}

remove_dir() {
  local d="$1"
  if [ -z "$d" ] || [ "$d" = "/" ]; then
    return 0
  fi
  if [ -d "$d" ]; then
    rm -rf "$d" || {
      echo "ERROR: Could not remove $d (permission denied?)." >&2
      echo "If you want a system-wide installation, run this script with sudo:" >&2
      echo "  sudo ./install/install.sh" >&2
      exit 1
    }
  fi
}

echo "tito-pdf Installation"
echo "===================="
echo ""
echo "Binary directory:  $BIN_DIR"
echo "Libexec directory: $LIBEXEC_DIR"
echo ""

# Remove existing installation if present
if [ -f "$INSTALL_MANIFEST" ] || [ -e "$BIN_DIR/tito-pdf" ] || [ -d "$LIBEXEC_DIR" ]; then
  echo "Existing tito-pdf installation detected. Removing recorded paths..."

  if [ -f "$INSTALL_MANIFEST" ]; then
    FILES=()
    DIRS=()

    while IFS= read -r line; do
      case "$line" in
        ''|\#*) continue ;;
        file=*) FILES+=("${line#file=}") ;;
        dir=*)  DIRS+=("${line#dir=}") ;;
      esac
    done < "$INSTALL_MANIFEST"

    for p in "${FILES[@]}"; do
      remove_file "$p"
    done
    for d in "${DIRS[@]}"; do
      remove_dir "$d"
    done
  else
    echo "Install manifest not found at $INSTALL_MANIFEST; removing default layout if present."
    remove_file "$BIN_DIR/tito-pdf"
    remove_dir "$LIBEXEC_DIR"
  fi

  echo ""
fi

# Create directories
if [ ! -d "$BIN_DIR" ]; then
  echo "Creating $BIN_DIR ..."
  mkdir -p "$BIN_DIR" || {
    echo "ERROR: Could not create $BIN_DIR (permission denied?)." >&2
    echo "If you want a system-wide installation, run this script with sudo:" >&2
    echo "  sudo ./install/install.sh" >&2
    exit 1
  }
fi

if [ ! -d "$LIBEXEC_DIR" ]; then
  echo "Creating $LIBEXEC_DIR ..."
  mkdir -p "$LIBEXEC_DIR" || {
    echo "ERROR: Could not create $LIBEXEC_DIR (permission denied?)." >&2
    echo "If you want a system-wide installation, run this script with sudo:" >&2
    echo "  sudo ./install/install.sh" >&2
    exit 1
  }
fi

# System deps
# - qpdf is required for PDF conversion
# - tesseract is recommended for OCR

# Best-effort install via brew (only when not root)
if ! command -v qpdf >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1 && [ "$(id -u)" != "0" ]; then
    echo "Attempting to install required dependency via Homebrew: qpdf"
    brew install qpdf || true
  fi
fi

if ! command -v qpdf >/dev/null 2>&1; then
  echo "ERROR: qpdf is required for PDF conversion but was not found on PATH." >&2
  echo "Install qpdf and re-run this installer:" >&2
  echo "  brew install qpdf" >&2
  exit 1
fi

if ! command -v tesseract >/dev/null 2>&1; then
  echo "WARNING: tesseract not found; OCR will be unavailable." >&2

  if command -v brew >/dev/null 2>&1 && [ "$(id -u)" != "0" ]; then
    echo "Attempting to install recommended dependency via Homebrew: tesseract"
    brew install tesseract || {
      echo "WARNING: Homebrew install failed; continuing without tesseract." >&2
    }
  else
    echo "Install it with Homebrew (recommended for OCR):" >&2
    echo "  brew install tesseract" >&2
  fi

  echo ""
fi

# Install runtime files
echo "Installing runtime assets into $LIBEXEC_DIR ..."
cp "$ROOT_DIR/tito-pdf" "$LIBEXEC_DIR/tito-pdf"
cp "$ROOT_DIR/requirements.txt" "$LIBEXEC_DIR/requirements.txt"
chmod +x "$LIBEXEC_DIR/tito-pdf" || true

# Create venv + install Python deps
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required." >&2
  exit 1
fi

echo "Creating venv at $VENV_DIR ..."
python3 -m venv "$VENV_DIR"

echo "Installing Python dependencies ..."
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null
"$VENV_DIR/bin/pip" install -r "$LIBEXEC_DIR/requirements.txt"

# Install launcher
LAUNCHER="$BIN_DIR/tito-pdf"
echo "Installing launcher to $LAUNCHER ..."
cat > "$LAUNCHER" <<EOF
#!/bin/bash
set -e
LIBEXEC_DIR="$LIBEXEC_DIR"
exec "$LIBEXEC_DIR/.venv/bin/python" "$LIBEXEC_DIR/tito-pdf" "\$@"
EOF
chmod +x "$LAUNCHER" || true

# BUILD_INFO
echo "Writing BUILD_INFO to $LIBEXEC_DIR/BUILD_INFO ..."
{
  echo "built_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"

  if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "git_commit=$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
    echo "git_describe=$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || true)"
  fi
} > "$LIBEXEC_DIR/BUILD_INFO" || {
  echo "WARNING: Could not write BUILD_INFO." >&2
}

# Install manifest
echo "Writing install manifest to $INSTALL_MANIFEST ..."
{
  echo "manifest_version=1"
  echo "installed_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"
  echo "bin_dir=$BIN_DIR"
  echo "libexec_dir=$LIBEXEC_DIR"
  echo "file=$LAUNCHER"
  echo "file=$INSTALL_MANIFEST"
  echo "file=$LIBEXEC_DIR/BUILD_INFO"
  echo "file=$LIBEXEC_DIR/tito-pdf"
  echo "file=$LIBEXEC_DIR/requirements.txt"
  echo "dir=$LIBEXEC_DIR"
} > "$INSTALL_MANIFEST"

echo ""
echo "Installation complete."
echo "Verify with:"
echo "  tito-pdf --help"
