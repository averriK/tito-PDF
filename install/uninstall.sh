#!/bin/bash
# Uninstall tito-pdf using install/manifest.json-defined installation paths.
#
# Usage:
#   ./install/uninstall.sh
#
# This script removes the launcher and libexec directory created by install/install.sh.
# It does not remove system packages (qpdf/ghostscript/tesseract).
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
  echo "Install jq (e.g. 'brew install jq') and re-run ./install/uninstall.sh" >&2
  exit 1
fi

BIN_DIR="$(jq -r '.binaries[0].install_dir' "$MANIFEST")"
LIBEXEC_DIR="$(jq -r '.libexec.install_dir' "$MANIFEST")"
INSTALL_MANIFEST="$LIBEXEC_DIR/INSTALL_MANIFEST"

remove_file() {
  local p="$1"
  if [ -z "$p" ] || [ "$p" = "/" ]; then
    return 0
  fi
  if [ -e "$p" ] || [ -L "$p" ]; then
    rm -f "$p" || {
      echo "ERROR: Failed to remove $p." >&2
      echo "If this is a system-wide installation, re-run this script with sudo:" >&2
      echo "  sudo ./install/uninstall.sh" >&2
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
      echo "ERROR: Failed to remove $d." >&2
      echo "If this is a system-wide installation, re-run this script with sudo:" >&2
      echo "  sudo ./install/uninstall.sh" >&2
      exit 1
    }
  fi
}

echo "tito-pdf Uninstallation"
echo "======================="
echo ""
echo "Binary directory:  $BIN_DIR"
echo "Libexec directory: $LIBEXEC_DIR"
echo ""

found_any=false

if [ -f "$INSTALL_MANIFEST" ]; then
  echo "Using install manifest at $INSTALL_MANIFEST"

  FILES=()
  DIRS=()

  while IFS= read -r line; do
    case "$line" in
      ''|\#*) continue ;;
      file=*) FILES+=("${line#file=}") ;;
      dir=*)  DIRS+=("${line#dir=}") ;;
      bin_dir=*) BIN_DIR="${line#bin_dir=}" ;;
      libexec_dir=*) LIBEXEC_DIR="${line#libexec_dir=}" ;;
    esac
  done < "$INSTALL_MANIFEST"

  for p in "${FILES[@]}"; do
    [ -z "$p" ] && continue
    if [ -e "$p" ] || [ -L "$p" ]; then
      found_any=true
      remove_file "$p"
    fi
  done

  for d in "${DIRS[@]}"; do
    [ -z "$d" ] && continue
    if [ -d "$d" ]; then
      found_any=true
      remove_dir "$d"
    fi
  done
else
  echo "Install manifest not found at $INSTALL_MANIFEST."
  echo "Will only remove the default layout if you confirm."
  read -r -p "Proceed with uninstall of default layout? [y/N] " CONFIRM
  case "$CONFIRM" in
    [yY]) ;;
    *) echo "Aborted by user."; exit 0 ;;
  esac

  if [ -e "$BIN_DIR/tito-pdf" ] || [ -L "$BIN_DIR/tito-pdf" ]; then
    found_any=true
    remove_file "$BIN_DIR/tito-pdf"
  fi
  if [ -d "$LIBEXEC_DIR" ]; then
    found_any=true
    remove_dir "$LIBEXEC_DIR"
  fi
fi

echo ""
if [ "$found_any" = false ]; then
  echo "tito-pdf not found in $BIN_DIR or $LIBEXEC_DIR. Nothing to uninstall."
else
  echo "Uninstallation complete for $BIN_DIR and $LIBEXEC_DIR."
fi

echo ""
if command -v tito-pdf >/dev/null 2>&1; then
  echo "WARNING: A tito-pdf command is still present in PATH after uninstall:" >&2
  command -v tito-pdf 2>/dev/null || true
  echo "If this is an old or manual installation, remove it manually." >&2
else
  echo "No tito-pdf command detected in PATH after uninstall."
fi
