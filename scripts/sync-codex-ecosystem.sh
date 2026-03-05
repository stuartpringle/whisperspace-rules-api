#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"

echo "[sync] syncing AGENTS stubs"
bash "${ROOT_SHARED}/sync-agents-stubs.sh"

echo "[sync] syncing CI workflow"
bash "${ROOT_SHARED}/sync-ci-workflow.sh"

echo "[sync] installing managed hooks"
bash /hdd/sites/stuartpringle/whisperspace-rules-api/scripts/install-codex-hooks-ecosystem.sh

echo "[sync] verifying managed hooks"
bash "${ROOT_SHARED}/verify-hooks.sh"
