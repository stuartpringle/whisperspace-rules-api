#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
TEMPLATE="${ROOT_SHARED}/templates/codex-audit-status.workflow.yml"
source "${ROOT_SHARED}/ecosystem-repos.sh"

for repo in "${WS_REPOS[@]}"; do
  if [[ ! -d "${repo}" ]]; then
    echo "WARN: missing repo path, skipping: ${repo}"
    continue
  fi
  if ! git -C "${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "WARN: not a git repo, skipping: ${repo}"
    continue
  fi

  mkdir -p "${repo}/.github/workflows"
  cp "${TEMPLATE}" "${repo}/.github/workflows/codex-audit-status.yml"
  echo "Synced CI workflow: ${repo}/.github/workflows/codex-audit-status.yml"
done
