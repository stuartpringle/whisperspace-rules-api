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

  pre_hook_path="$(git -C "${repo}" rev-parse --git-path hooks)/pre-commit"
  post_hook_path="$(git -C "${repo}" rev-parse --git-path hooks)/post-commit"
  if [[ ! -f "${pre_hook_path}" ]]; then
    echo "FAIL: missing pre-commit hook: ${repo}"
    fail=1
    continue
  fi

  if [[ ! -f "${post_hook_path}" ]]; then
    echo "FAIL: missing post-commit hook: ${repo}"
    fail=1
    continue
  fi

  if ! grep -q "WS_CODEX_MANAGED_PRECOMMIT" "${pre_hook_path}" 2>/dev/null; then
    echo "FAIL: unmanaged pre-commit hook: ${repo}"
    fail=1
    continue
  fi

  if ! grep -q "WS_CODEX_MANAGED_POSTCOMMIT" "${post_hook_path}" 2>/dev/null; then
    echo "FAIL: unmanaged post-commit hook: ${repo}"
    fail=1
    continue
  fi

  if ! grep -q "/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/pre-commit-managed.sh" "${pre_hook_path}" 2>/dev/null; then
    echo "FAIL: pre-commit hook does not target shared runtime: ${repo}"
    fail=1
    continue
  fi

  if ! grep -q "/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/post-commit-managed.sh" "${post_hook_path}" 2>/dev/null; then
    echo "FAIL: post-commit hook does not target shared runtime: ${repo}"
    fail=1
    continue
  fi

  echo "OK: ${repo}"
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "All repo hooks verified."
