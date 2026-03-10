#!/usr/bin/env bash

set -e  # exit immediately if any command fails

ROOT="${WS_ECOSYSTEM_ROOT:-/hdd/sites/whisperspace}"
LEGACY_ROOT="${WS_LEGACY_ECOSYSTEM_ROOT:-/hdd/sites/stuartpringle}"

resolve_repo_path() {
  local preferred="${1:-}"
  local legacy="${2:-}"
  if [[ -n "${preferred}" && -d "${preferred}" ]]; then
    printf '%s\n' "${preferred}"
    return 0
  fi
  printf '%s\n' "${legacy}"
}

RULES_API_REPO="$(resolve_repo_path "${ROOT}/rules-api" "${LEGACY_ROOT}/whisperspace-rules-api")"
CHARACTER_BUILDER_REPO="$(resolve_repo_path "${ROOT}/character-builder" "${LEGACY_ROOT}/whisperspace-character-builder")"
SDK_REPO="$(resolve_repo_path "${ROOT}/sdk" "${LEGACY_ROOT}/whisperspace-sdk")"
LEGACY_OBR_EXTENSION_REPO="${LEGACY_ROOT}/whisperspace-obr-extension"

PROJECTS=(
  "${CHARACTER_BUILDER_REPO}"
  "${LEGACY_OBR_EXTENSION_REPO}"
  "${RULES_API_REPO}"
  "${SDK_REPO}"
)

echo "➡️  Running rules:publish in whisperspace-rules-api"
cd "${RULES_API_REPO}"
npm run rules:publish

echo "✅ rules:publish complete"
echo

for project in "${PROJECTS[@]}"; do
  echo "➡️  Building $project"
  cd "$project"
  npm run build
  echo "✅ Finished building $project"
  echo
done

echo "🎉 All builds completed successfully"
