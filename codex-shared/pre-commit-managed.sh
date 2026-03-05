#!/usr/bin/env bash
# WS_CODEX_MANAGED_PRECOMMIT
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
USER_HOOK_PATH="$(git rev-parse --git-path hooks)/pre-commit.user"

has_pattern() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q "${pattern}" "${file}" 2>/dev/null
  else
    grep -q "${pattern}" "${file}" 2>/dev/null
  fi
}

run_user_hook() {
  if [[ -x "${USER_HOOK_PATH}" ]]; then
    # Skip legacy managed hooks to prevent recursive audit loops.
    if has_pattern "WS_CODEX_MANAGED_PRECOMMIT|codex:audit:batch" "${USER_HOOK_PATH}"; then
      echo "[pre-commit] skipping recursive legacy managed user hook: ${USER_HOOK_PATH}"
      return 0
    fi
    echo "[pre-commit] running preserved user hook: ${USER_HOOK_PATH}"
    "${USER_HOOK_PATH}"
  fi
}

if [[ "${WS_SKIP_CODEX_AUDIT:-0}" == "1" ]]; then
  echo "[pre-commit] codex audit skipped (WS_SKIP_CODEX_AUDIT=1)"
  run_user_hook
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

run_user_hook

if [[ -z "$(git diff --cached --name-only)" ]]; then
  exit 0
fi

if [[ -f package.json ]] && has_pattern '"codex:audit:batch"' package.json; then
  echo "[pre-commit] running npm run codex:audit:batch"
  npm run codex:audit:batch
else
  bash "${ROOT_SHARED}/codex-batch-audit.sh" --staged
fi

echo "[pre-commit] running documentation audit"
bash "${ROOT_SHARED}/codex-docs-audit.sh"

echo "[pre-commit] checking unresolved audit findings"
bash "${ROOT_SHARED}/audit-status.sh"
