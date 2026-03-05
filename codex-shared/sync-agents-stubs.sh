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
3. Run guardrail audit before commit:
   - Preferred: `npm run codex:audit:batch` (if available in this repo).
   - Fallback: `git diff --staged | codex exec "Audit this diff for security/workflow/docs drift. Return critical/high findings first."`
4. Run documentation audit before commit:
   - Preferred: `npm run codex:audit:docs` (if available in this repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/codex-docs-audit.sh`
5. Run auto-resolution sweep for closed findings:
   - Preferred: `npm run codex:audit:autoresolve` (if available in this repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/audit-autoresolve.sh`
6. Resolve critical/high audit findings before commit.
7. Keep ecosystem guardrails synchronized after helper/policy updates:
   - Preferred: `npm run codex:ecosystem:sync` (from rules-api control repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/scripts/sync-codex-ecosystem.sh`
8. Keep this repo README integration-focused and update /hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md whenever contracts/auth/release workflow/shared behavior changes.

Repo-specific additions:
- Keep this section minimal and only add true local exceptions.
EOF

  echo "Synced AGENTS stub: ${repo}/AGENTS.md"
done
