#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ci:post-commit-gate ERROR: not in a git repository."
  exit 2
fi

echo "[ci:post-commit-gate] running codex post-commit review on HEAD"
bash "${ROOT_SHARED}/post-commit-review.sh" HEAD

echo "[ci:post-commit-gate] enforcing strict post-commit high/critical gate"
WS_AUDIT_STATUS_STRICT=1 WS_AUDIT_STATUS_REPORT_SCOPE=post-commit \
  bash "${ROOT_SHARED}/audit-status.sh"

echo "[ci:post-commit-gate] PASS"
