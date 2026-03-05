#!/usr/bin/env bash
set -euo pipefail

PARSER_ROOT="/hdd/sites/stuartpringle/whisperspace-rules-parser"
PARSER_OUT="${PARSER_ROOT}/out"

echo "[rules:publish] Running rules parser (validate + diff)..."
(
  cd "${PARSER_ROOT}"
  PYTHONPATH="${PARSER_ROOT}/src" python3 -m whisperspace_rules_parser.cli --out "${PARSER_OUT}" --validate --diff
)

echo "[rules:publish] Running compatibility gate..."
npm run compat:check

if [[ "${WS_SKIP_CHARACTER_AUTH_TEST:-0}" == "1" ]]; then
  echo "[rules:publish] Skipping character ownership regression test (WS_SKIP_CHARACTER_AUTH_TEST=1)."
else
  echo "[rules:publish] Running character ownership regression test..."
  npm run test:character-auth
fi

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

echo "[rules:publish] Publishing character API endpoints..."
CHAR_API_SRC="public/character-api"
CHAR_API_DEST="/hdd/sites/stuartpringle/whisperspace-rules-api/dist/character-api"
mkdir -p "$CHAR_API_DEST"
cp "$CHAR_API_SRC/index.php" "$CHAR_API_DEST/index.php"
cp "$CHAR_API_SRC/.htaccess" "$CHAR_API_DEST/.htaccess"
if [[ -f "$CHAR_API_SRC/.env.example" ]]; then
  cp "$CHAR_API_SRC/.env.example" "$CHAR_API_DEST/.env.example"
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

if [[ "${WS_SKIP_CONTRACT_SMOKE:-0}" == "1" ]]; then
  echo "[rules:publish] Skipping contract smoke verification (WS_SKIP_CONTRACT_SMOKE=1)."
else
  echo "[rules:publish] Running contract smoke verification..."
  npm run contract:smoke
fi
