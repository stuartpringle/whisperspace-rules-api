#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
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
  if [[ "${repo}" == "/hdd/sites/stuartpringle/whisperspace-rules-api" ]]; then
    echo "INFO: canonical AGENTS kept in place: ${repo}/AGENTS.md"
    continue
  fi

  cat > "${repo}/AGENTS.md" <<'EOF'
# AGENTS

Canonical policy source:
- /hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md

Shared helper scripts (single source of truth):
- /hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/

Mandatory controls for this repo (do not skip):
1. Read canonical policy + security context:
   - /hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md
   - /hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md
   - /hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-SECURITY.md
2. At startup and after each commit, run audit status and report unresolved findings:
   - Preferred: `npm run codex:audit:status` (if available in this repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/audit-status.sh`
3. Pre-commit fast checks are default:
   - Always-on lightweight checks: `git diff --cached --check` + audit status.
4. Post-commit queues asynchronous commit-scoped Codex review:
   - Queue file: `.codex/audits/post-commit-queue.tsv`.
   - Manual run fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/post-commit-review.sh <commit>`.
5. Run auto-resolution sweep for closed findings:
   - Preferred: `npm run codex:audit:autoresolve` (if available in this repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/audit-autoresolve.sh`
6. Resolve critical/high audit findings before merge.
7. Keep ecosystem guardrails synchronized after helper/policy updates:
   - Preferred: `npm run codex:ecosystem:sync` (from rules-api control repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/scripts/sync-codex-ecosystem.sh`
8. Keep this repo README integration-focused and update /hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md whenever contracts/auth/release workflow/shared behavior changes.
9. Treat scheduled Claude ecosystem audit cron as set-once + verify:
   - Preferred check: `npm run claude:audit:cron:check` (from rules-api control repo).
   - Preferred install/update only when missing or drifted: `npm run claude:audit:cron:install -- 7`.
   - Fallback check: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/check-claude-audit-cron.sh`
   - Fallback install/update: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/install-claude-audit-cron.sh 7`

Repo-specific additions:
- Keep this section minimal and only add true local exceptions.
EOF

  echo "Synced AGENTS stub: ${repo}/AGENTS.md"
done
