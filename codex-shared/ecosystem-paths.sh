#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${WS_ECOSYSTEM_PATHS_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
WS_ECOSYSTEM_PATHS_LOADED=1

_ws_this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WS_SHARED_ROOT="${WS_SHARED_ROOT:-${_ws_this_dir}}"
WS_CONTROL_ROOT="${WS_CONTROL_ROOT:-$(cd "${WS_SHARED_ROOT}/.." && pwd)}"
WS_ECOSYSTEM_ROOT="${WS_ECOSYSTEM_ROOT:-/hdd/sites/whisperspace}"
WS_LEGACY_ECOSYSTEM_ROOT="${WS_LEGACY_ECOSYSTEM_ROOT:-/hdd/sites/stuartpringle}"

if [[ -f "${WS_ECOSYSTEM_ROOT}/AGENTS.md" ]]; then
  WS_POLICY_ROOT="${WS_ECOSYSTEM_ROOT}"
else
  WS_POLICY_ROOT="${WS_CONTROL_ROOT}"
fi

WS_AGENTS_PATH="${WS_POLICY_ROOT}/AGENTS.md"
WS_PROJECT_OVERVIEW_PATH="${WS_POLICY_ROOT}/PROJECT-OVERVIEW.md"
WS_PROJECT_SECURITY_PATH="${WS_POLICY_ROOT}/PROJECT-SECURITY.md"
WS_AUDIT_HOME="${WS_AUDIT_HOME:-${WS_POLICY_ROOT}/.codex}"
WS_AUDIT_ARTIFACTS_DIR="${WS_AUDIT_HOME}/audits"

export WS_SHARED_ROOT
export WS_CONTROL_ROOT
export WS_ECOSYSTEM_ROOT
export WS_LEGACY_ECOSYSTEM_ROOT
export WS_POLICY_ROOT
export WS_AGENTS_PATH
export WS_PROJECT_OVERVIEW_PATH
export WS_PROJECT_SECURITY_PATH
export WS_AUDIT_HOME
export WS_AUDIT_ARTIFACTS_DIR

declare -ag WS_REPO_KEYS=(
  "site"
  "character-builder"
  "developer"
  "docs"
  "obr-extension-legacy"
  "obr-gm"
  "obr-rules-extension"
  "obr-sheet"
  "rules-api"
  "rules-parser"
  "sdk"
)

declare -Ag WS_REPO_SLUGS=(
  ["site"]="whisperspace"
  ["character-builder"]="whisperspace-character-builder"
  ["developer"]="whisperspace-developer"
  ["docs"]="whisperspace-docs"
  ["obr-extension-legacy"]="whisperspace-obr-extension"
  ["obr-gm"]="whisperspace-obr-gm"
  ["obr-rules-extension"]="whisperspace-obr-rules-extension"
  ["obr-sheet"]="whisperspace-obr-sheet"
  ["rules-api"]="whisperspace-rules-api"
  ["rules-parser"]="whisperspace-rules-parser"
  ["sdk"]="whisperspace-sdk"
)

declare -Ag WS_REPO_PATHS_NEW=(
  ["site"]="${WS_ECOSYSTEM_ROOT}/site"
  ["character-builder"]="${WS_ECOSYSTEM_ROOT}/character-builder"
  ["developer"]="${WS_ECOSYSTEM_ROOT}/developer"
  ["docs"]="${WS_ECOSYSTEM_ROOT}/docs"
  ["obr-gm"]="${WS_ECOSYSTEM_ROOT}/obr/gm"
  ["obr-rules-extension"]="${WS_ECOSYSTEM_ROOT}/obr/rules-extension"
  ["obr-sheet"]="${WS_ECOSYSTEM_ROOT}/obr/sheet"
  ["rules-api"]="${WS_ECOSYSTEM_ROOT}/rules-api"
  ["rules-parser"]="${WS_ECOSYSTEM_ROOT}/rules-parser"
  ["sdk"]="${WS_ECOSYSTEM_ROOT}/sdk"
)

declare -Ag WS_REPO_PATHS_LEGACY=(
  ["site"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace"
  ["character-builder"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-character-builder"
  ["developer"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-developer"
  ["docs"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-docs"
  ["obr-extension-legacy"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-obr-extension"
  ["obr-gm"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-obr-gm"
  ["obr-rules-extension"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-obr-rules-extension"
  ["obr-sheet"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-obr-sheet"
  ["rules-api"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-rules-api"
  ["rules-parser"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-rules-parser"
  ["sdk"]="${WS_LEGACY_ECOSYSTEM_ROOT}/whisperspace-sdk"
)

ws_repo_slug() {
  local key="${1:-}"
  printf '%s\n' "${WS_REPO_SLUGS[${key}]:-}"
}

ws_repo_path() {
  local key="${1:-}"
  local preferred="${WS_REPO_PATHS_NEW[${key}]:-}"
  local legacy="${WS_REPO_PATHS_LEGACY[${key}]:-}"

  if [[ -n "${preferred}" && -d "${preferred}" ]]; then
    printf '%s\n' "${preferred}"
    return 0
  fi
  if [[ -n "${legacy}" && -d "${legacy}" ]]; then
    printf '%s\n' "${legacy}"
    return 0
  fi
  if [[ -n "${preferred}" ]]; then
    printf '%s\n' "${preferred}"
    return 0
  fi
  printf '%s\n' "${legacy}"
}

ws_all_repo_paths() {
  local key
  for key in "${WS_REPO_KEYS[@]}"; do
    ws_repo_path "${key}"
  done
}

ws_repo_notes_paths() {
  local repo_path="${1:-}"
  if [[ -z "${repo_path}" ]]; then
    return 0
  fi
  printf '%s\n' "${repo_path}/.codex/PROJECT-HISTORY.md"
  printf '%s\n' "${repo_path}/.codex/NEXT-STEPS.md"
  printf '%s\n' "${repo_path}/.codex/AUDIT-LOG.md"
}
