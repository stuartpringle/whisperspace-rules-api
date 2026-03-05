#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
source "${ROOT_SHARED}/ecosystem-repos.sh"

fail=0
for repo in "${WS_REPOS[@]}"; do
  if [[ ! -d "${repo}" ]]; then
    echo "WARN: missing repo path, skipping: ${repo}"
    continue
  fi
  if ! git -C "${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "WARN: not a git repo, skipping: ${repo}"
    continue
  fi

  hook_path="$(git -C "${repo}" rev-parse --git-path hooks)/pre-commit"
  if [[ ! -f "${hook_path}" ]]; then
    echo "FAIL: missing pre-commit hook: ${repo}"
    fail=1
    continue
  fi

  if ! grep -q "WS_CODEX_MANAGED_PRECOMMIT" "${hook_path}" 2>/dev/null; then
    echo "FAIL: unmanaged pre-commit hook: ${repo}"
    fail=1
    continue
  fi

  if ! grep -q "/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/pre-commit-managed.sh" "${hook_path}" 2>/dev/null; then
    echo "FAIL: hook does not target shared runtime: ${repo}"
    fail=1
    continue
  fi

  echo "OK: ${repo}"
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "All repo hooks verified."
