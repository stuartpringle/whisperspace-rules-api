#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ecosystem-paths.sh"
ROOT_SHARED="${WS_SHARED_ROOT}"
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
  if [[ "${repo}" == "$(ws_repo_path rules-api)" ]]; then
    echo "INFO: canonical AGENTS kept in place: ${repo}/AGENTS.md"
    continue
  fi

  tmp_stub="$(mktemp)"
  cat > "${tmp_stub}" <<'EOF'
# AGENTS

Canonical policy source:
- __WS_AGENTS_PATH__

Shared helper scripts (single source of truth):
- __WS_SHARED_ROOT__/

Mandatory controls for this repo (do not skip):
1. Read canonical policy + security context:
   - __WS_AGENTS_PATH__
   - __WS_PROJECT_OVERVIEW_PATH__
   - __WS_PROJECT_SECURITY_PATH__
2. Prefer opening Codex from the ecosystem workspace root when present:
   - `__WS_ECOSYSTEM_ROOT__`
   - Treat this repo as one project within that broader workspace.
3. Keep local repo notes current for handoff/context:
   - `.codex/PROJECT-HISTORY.md`
   - `.codex/NEXT-STEPS.md`
   - `.codex/AUDIT-LOG.md`
4. At startup and after each commit, run audit status and report unresolved findings:
   - Preferred: `npm run codex:audit:status` (if available in this repo).
   - Fallback: `__WS_SHARED_ROOT__/audit-status.sh`
5. Pre-commit fast checks are default:
   - Always-on lightweight checks: `git diff --cached --check` + audit status.
6. Post-commit queues asynchronous commit-scoped Codex review:
   - Queue file: `.codex/audits/post-commit-queue.tsv`.
   - Manual run fallback: `__WS_SHARED_ROOT__/post-commit-review.sh <commit>`.
7. Merge-time blocking gate is required:
   - Preferred: `npm run codex:audit:ci:post-commit-gate` (if available).
   - Fallback: `__WS_SHARED_ROOT__/ci-post-commit-gate.sh`
8. Run auto-resolution sweep for closed findings:
   - Preferred: `npm run codex:audit:autoresolve` (if available in this repo).
   - Fallback: `__WS_SHARED_ROOT__/audit-autoresolve.sh`
9. Resolve critical/high audit findings before merge.
10. Keep ecosystem guardrails synchronized after helper/policy updates:
   - Preferred: `npm run codex:ecosystem:sync` (from rules-api control repo).
   - Fallback: `__WS_CONTROL_ROOT__/scripts/sync-codex-ecosystem.sh`
11. Keep this repo README integration-focused and update __WS_PROJECT_OVERVIEW_PATH__ whenever contracts/auth/release workflow/shared behavior changes.
12. Treat scheduled Claude ecosystem audit cron as set-once + verify:
   - Preferred check: `npm run claude:audit:cron:check` (from rules-api control repo).
   - Preferred install/update only when missing or drifted: `npm run claude:audit:cron:install -- 7`.
   - Fallback check: `__WS_SHARED_ROOT__/check-claude-audit-cron.sh`
   - Fallback install/update: `__WS_SHARED_ROOT__/install-claude-audit-cron.sh 7`

Repo-specific additions:
- Keep this section minimal and only add true local exceptions.
EOF
  sed \
    -e "s|__WS_AGENTS_PATH__|${WS_AGENTS_PATH}|g" \
    -e "s|__WS_PROJECT_OVERVIEW_PATH__|${WS_PROJECT_OVERVIEW_PATH}|g" \
    -e "s|__WS_PROJECT_SECURITY_PATH__|${WS_PROJECT_SECURITY_PATH}|g" \
    -e "s|__WS_SHARED_ROOT__|${WS_SHARED_ROOT}|g" \
    -e "s|__WS_CONTROL_ROOT__|${WS_CONTROL_ROOT}|g" \
    -e "s|__WS_ECOSYSTEM_ROOT__|${WS_ECOSYSTEM_ROOT}|g" \
    "${tmp_stub}" > "${repo}/AGENTS.md"
  rm -f "${tmp_stub}"

  echo "Synced AGENTS stub: ${repo}/AGENTS.md"
done
