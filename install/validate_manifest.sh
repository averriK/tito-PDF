#!/bin/bash
# Validate install/manifest.json for basic completeness.
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
  exit 1
fi

BIN_DIR="$(jq -r '.binaries[0].install_dir' "$MANIFEST")"
LIBEXEC_DIR="$(jq -r '.libexec.install_dir' "$MANIFEST")"

if [ -z "$BIN_DIR" ] || [ "$BIN_DIR" = "null" ]; then
  echo "ERROR: manifest missing .binaries[0].install_dir" >&2
  exit 1
fi

if [ -z "$LIBEXEC_DIR" ] || [ "$LIBEXEC_DIR" = "null" ]; then
  echo "ERROR: manifest missing .libexec.install_dir" >&2
  exit 1
fi

if [ ! -f "$ROOT_DIR/tito-pdf" ]; then
  echo "ERROR: expected tito-pdf script at $ROOT_DIR/tito-pdf" >&2
  exit 1
fi

if [ ! -f "$ROOT_DIR/requirements.txt" ]; then
  echo "ERROR: expected requirements.txt at $ROOT_DIR/requirements.txt" >&2
  exit 1
fi

echo "OK: manifest defines BIN_DIR=$BIN_DIR and LIBEXEC_DIR=$LIBEXEC_DIR"
