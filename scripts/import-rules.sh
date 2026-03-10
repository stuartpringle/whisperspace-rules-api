#!/usr/bin/env bash
set -euo pipefail

WS_ECOSYSTEM_ROOT="${WS_ECOSYSTEM_ROOT:-/hdd/sites/whisperspace}"
WS_LEGACY_ECOSYSTEM_ROOT="${WS_LEGACY_ECOSYSTEM_ROOT:-/hdd/sites/stuartpringle}"
DEFAULT_SRC_DIR="${WS_ECOSYSTEM_ROOT}/rules-parser/out"
if [[ ! -d "${DEFAULT_SRC_DIR}" ]]; then
  DEFAULT_SRC_DIR="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-rules-parser/out"
fi
SRC_DIR="${1:-${DEFAULT_SRC_DIR}}"
DEST_DIR="src/data/rules"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "[import-rules] Source directory not found: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
rm -f "$DEST_DIR"/*.yaml
cp "$SRC_DIR"/*.yaml "$DEST_DIR"/

echo "[import-rules] Copied YAML files from $SRC_DIR to $DEST_DIR"

if [[ -d "$SRC_DIR/assets" ]]; then
  echo "[import-rules] Syncing assets..."
  rm -rf "$DEST_DIR/assets"
  cp -R "$SRC_DIR/assets" "$DEST_DIR/assets"
fi

echo "[import-rules] Parsing gear tables..."
node scripts/parse-gear.mjs

echo "[import-rules] Regenerating JSON..."
npm run generate:data
