#!/usr/bin/env bash

set -e  # exit immediately if any command fails

ROOT="/hdd/sites/stuartpringle"

PROJECTS=(
  "whisperspace-character-builder"
  "whisperspace-obr-extension"
  "whisperspace-rules-api"
  "whisperspace-sdk"
)

echo "➡️  Running rules:publish in whisperspace-rules-api"
cd "$ROOT/whisperspace-rules-api"
npm run rules:publish

echo "✅ rules:publish complete"
echo

for project in "${PROJECTS[@]}"; do
  echo "➡️  Building $project"
  cd "$ROOT/$project"
  npm run build
  echo "✅ Finished building $project"
  echo
done

echo "🎉 All builds completed successfully"
