#!/usr/bin/env bash
set -euo pipefail

PARSER_ROOT="/hdd/sites/stuartpringle/whisperspace-rules-parser"
PARSER_OUT="${PARSER_ROOT}/out"

echo "[rules:publish] Running rules parser (validate + diff)..."
(
  cd "${PARSER_ROOT}"
  PYTHONPATH="${PARSER_ROOT}/src" python3 -m whisperspace_rules_parser.cli --out "${PARSER_OUT}" --validate --diff
)

echo "[rules:publish] Building core HTTP module..."
bash scripts/core-build.sh

echo "[rules:publish] Syncing parser output + generating API bundle..."
bash scripts/import-rules.sh "${PARSER_OUT}"

echo "[rules:publish] Skipping SDK version sync (external repo)."

echo "[rules:publish] Publishing calc endpoints..."
CALC_SRC="public/rules-api/calc"
CALC_DEST="/hdd/sites/stuartpringle/whisperspace-rules-api/public/rules-api/calc"
if [[ "$(realpath -m "$CALC_SRC")" == "$(realpath -m "$CALC_DEST")" ]]; then
  echo "[rules:publish] Calc endpoints already in publish dir; skipping copy."
else
  mkdir -p "$CALC_DEST"
  cp "$CALC_SRC/index.php" "$CALC_DEST/index.php"
  cp "$CALC_SRC/.htaccess" "$CALC_DEST/.htaccess"
  mkdir -p "$CALC_DEST/schemas"
  cp "$CALC_SRC/schemas/"*.json "$CALC_DEST/schemas/"
fi

if [ -f "index.html" ]; then
  echo "[rules:publish] Building Vite dist..."
  npm run build
  if [ -f "public/.htaccess" ]; then
    cp "public/.htaccess" "dist/.htaccess"
    echo "[rules:publish] Copied public/.htaccess to dist/.htaccess"
  fi
else
  echo "[rules:publish] Skipping Vite dist build (index.html not found)."
fi
