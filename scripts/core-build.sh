#!/usr/bin/env bash
set -euo pipefail

REPO_OUT="public/rules-api/latest/core"
PUBLISH_OUT="/hdd/sites/stuartpringle/whisperspace-rules-api/public/rules-api/latest/core"
REPO_OUT_ABS="$(realpath -m "$REPO_OUT")"
PUBLISH_OUT_ABS="$(realpath -m "$PUBLISH_OUT")"

rm -rf "$REPO_OUT"
mkdir -p "$REPO_OUT"

if [[ ! -d "packages/core/node_modules" ]]; then
  echo "[core:build] Installing core dependencies..."
  (cd packages/core && npm install)
fi

echo "[core:build] Building core module to ${REPO_OUT}"
./node_modules/.bin/tsc -p packages/core/tsconfig.json --outDir "$REPO_OUT"

if [[ "$REPO_OUT_ABS" == "$PUBLISH_OUT_ABS" ]]; then
  echo "[core:build] Publish dir matches build output; skipping copy."
else
  mkdir -p "$PUBLISH_OUT"
  rm -rf "$PUBLISH_OUT"
  cp -R "$REPO_OUT" "$PUBLISH_OUT"
  echo "[core:build] Published core module to ${PUBLISH_OUT}"
fi
