#!/usr/bin/env bash
set -euo pipefail

echo "[publish:runtime] Publishing character API endpoints..."
CHAR_API_SRC="public/character-api"
CHAR_API_DEST="${PWD}/dist/character-api"
mkdir -p "${CHAR_API_DEST}"
cp "${CHAR_API_SRC}/index.php" "${CHAR_API_DEST}/index.php"
cp "${CHAR_API_SRC}/.htaccess" "${CHAR_API_DEST}/.htaccess"
if [[ -f "${CHAR_API_SRC}/.env.example" ]]; then
  cp "${CHAR_API_SRC}/.env.example" "${CHAR_API_DEST}/.env.example"
fi

if [[ -f "index.html" ]]; then
  echo "[publish:runtime] Building Vite dist..."
  npm run build
  if [[ -f "public/.htaccess" ]]; then
    cp "public/.htaccess" "dist/.htaccess"
    echo "[publish:runtime] Copied public/.htaccess to dist/.htaccess"
  fi
else
  echo "[publish:runtime] Skipping Vite dist build (index.html not found)."
fi
