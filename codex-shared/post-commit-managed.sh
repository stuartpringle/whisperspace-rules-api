#!/usr/bin/env bash
# WS_CODEX_MANAGED_POSTCOMMIT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ecosystem-paths.sh"
ROOT_SHARED="${WS_SHARED_ROOT}"
USER_HOOK_PATH="$(git rev-parse --git-path hooks)/post-commit.user"
QUEUE_PATH=".codex/audits/post-commit-queue.tsv"

run_user_hook() {
  if [[ -x "${USER_HOOK_PATH}" ]]; then
    echo "[post-commit] running preserved user hook: ${USER_HOOK_PATH}"
    "${USER_HOOK_PATH}"
  fi
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

run_user_hook

# Codex post-commit audits are disabled by default for now (2026-10-28): the local Codex
# model config is failing. Set WS_ENABLE_POST_COMMIT_CODEX_AUDIT=1 to queue audits again.
if [[ "${WS_ENABLE_POST_COMMIT_CODEX_AUDIT:-0}" != "1" ]]; then
  exit 0
fi

if [[ "${WS_SKIP_POST_COMMIT_CODEX_AUDIT:-0}" == "1" ]]; then
  echo "[post-commit] skipped (WS_SKIP_POST_COMMIT_CODEX_AUDIT=1)"
  exit 0
fi

commit_hash="$(git rev-parse HEAD)"
mkdir -p .codex/audits
printf '%s\t%s\n' "$(date -u +%s)" "${commit_hash}" >> "${QUEUE_PATH}"

if bash "${ROOT_SHARED}/post-commit-worker.sh" --ensure-running >/dev/null 2>&1; then
  echo "[post-commit] queued codex audit for commit ${commit_hash}"
else
  echo "[post-commit] WARN: failed to start post-commit worker for ${commit_hash}"
fi
