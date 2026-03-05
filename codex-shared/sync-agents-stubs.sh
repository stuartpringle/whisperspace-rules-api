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
3. Pre-commit fast-path is default:
   - Always-on lightweight checks: `git diff --cached --check` + audit status.
   - Trigger source: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/risk-trigger.sh`.
   - Full codex subprocess audits (`codex:audit:batch`, `codex:audit:docs`) run for code/config/workflow/security/API/schema paths and fail closed for non-allowlisted paths.
   - Full audits are skipped only when all changed files are in the low-risk allowlist (docs/static assets).
4. Force a full codex subprocess audit with `WS_FORCE_FULL_CODEX_AUDIT=1` when needed.
5. Emergency bypass is explicit only:
   - `WS_SKIP_CODEX_AUDIT=1` requires `WS_MANUAL_AUDIT_ACK=I_RAN_CODEX_AUDITS` and `WS_BYPASS_REASON="<ticket or short reason>"` after manual batch/docs audits.
   - Risk-triggered changes still require full subprocess audits unless `WS_ALLOW_RISKY_SKIP=1` is also set.
   - Every emergency bypass is written to `.codex/BYPASS-LOG.tsv` and surfaced by audit status.
6. Run auto-resolution sweep for closed findings:
   - Preferred: `npm run codex:audit:autoresolve` (if available in this repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/audit-autoresolve.sh`
7. Resolve critical/high audit findings before commit.
8. Keep ecosystem guardrails synchronized after helper/policy updates:
   - Preferred: `npm run codex:ecosystem:sync` (from rules-api control repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/scripts/sync-codex-ecosystem.sh`
9. Keep this repo README integration-focused and update /hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md whenever contracts/auth/release workflow/shared behavior changes.
10. Keep scheduled Claude ecosystem audits active via user crontab:
   - Preferred: `npm run claude:audit:cron:install -- 7` (from rules-api control repo).
   - Fallback: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/install-claude-audit-cron.sh 7`

Repo-specific additions:
- Keep this section minimal and only add true local exceptions.
EOF

  echo "Synced AGENTS stub: ${repo}/AGENTS.md"
done
