#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ecosystem-paths.sh"

DAYS="${1:-7}"
ROOT="${WS_ECOSYSTEM_ROOT}"
if [[ ! -d "${ROOT}" ]]; then
  ROOT="${WS_LEGACY_ECOSYSTEM_ROOT}"
fi
OUT_DIR="${WS_AUDIT_ARTIFACTS_DIR}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
PROMPT_PATH="${OUT_DIR}/claude-scheduled-audit-${TS}.prompt.txt"
REPORT_PATH="${OUT_DIR}/claude-scheduled-audit-${TS}.txt"
TIMEOUT_SEC="${WS_CLAUDE_AUDIT_TIMEOUT_SEC:-}"

source "${WS_SHARED_ROOT}/ecosystem-repos.sh"
DEFAULT_REPOS=("${WS_REPOS[@]}")

REPOS=("${DEFAULT_REPOS[@]}")
if [[ -n "${WS_CLAUDE_AUDIT_REPOS:-}" ]]; then
  IFS=',' read -r -a REPOS <<< "${WS_CLAUDE_AUDIT_REPOS}"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "claude:audit:repo ERROR: claude CLI not found."
  exit 2
fi

mkdir -p "${OUT_DIR}"

{
  cat <<EOF
You are running a scheduled Whisperspace ecosystem audit.

Use local file reads and git history only. Do not invent state.
Audit window: last ${DAYS} days.

Canonical policy/docs to review first:
- ${WS_AGENTS_PATH}
- ${WS_CONTROL_ROOT}/README.md
- ${WS_PROJECT_OVERVIEW_PATH}
- ${WS_PROJECT_SECURITY_PATH}
- ${WS_SHARED_ROOT}/README.md

Then review these repos:
EOF
  for repo in "${REPOS[@]}"; do
    printf -- "- %s\n" "${repo}"
  done
  cat <<EOF

For each repo, check:
1) AGENTS policy alignment with canonical source.
2) README integration contract quality (schemas/endpoints/auth/build/publish notes where applicable).
3) Workflow/security drift relative to PROJECT-OVERVIEW and PROJECT-SECURITY.
4) Changes in the last ${DAYS} days that required docs updates but did not receive them.

Use git commands in each repo for recent history and changed files.

Return exactly this format:
CLAUDE_AUDIT_STATUS: PASS|FAIL
SEVERITY_COUNTS: critical=<n> high=<n> medium=<n> low=<n>
TOP_ACTIONS:
1. <action>
2. <action>
3. <action>
FINDINGS:
- [severity][repo-or-path] issue | remediation
- none
EOF
} > "${PROMPT_PATH}"

if [[ -n "${TIMEOUT_SEC}" ]] && command -v timeout >/dev/null 2>&1; then
  if ! cat "${PROMPT_PATH}" | timeout "${TIMEOUT_SEC}" claude -p --permission-mode bypassPermissions --output-format text --add-dir "${ROOT}" > "${REPORT_PATH}"; then
    echo "claude:audit:repo ERROR: timed out or failed (timeout=${TIMEOUT_SEC}s)."
    exit 124
  fi
else
  cat "${PROMPT_PATH}" | claude -p --permission-mode bypassPermissions --output-format text --add-dir "${ROOT}" > "${REPORT_PATH}"
fi

if [[ ! -s "${REPORT_PATH}" ]]; then
  echo "claude:audit:repo ERROR: empty report output."
  exit 6
fi

echo "claude:audit:repo report: ${REPORT_PATH}"
