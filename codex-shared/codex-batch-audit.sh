#!/usr/bin/env bash
set -euo pipefail

MODE="staged"
SOFT_FAIL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged)
      MODE="staged"
      shift
      ;;
    --working-tree)
      MODE="working"
      shift
      ;;
    --soft-fail)
      SOFT_FAIL=1
      shift
      ;;
    *)
      echo "Usage: $0 [--staged|--working-tree] [--soft-fail]"
      exit 2
      ;;
  esac
done

if ! command -v codex >/dev/null 2>&1; then
  echo "codex:audit:batch WARN: codex CLI not found; skipping audit."
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "codex:audit:batch ERROR: not in a git repository."
  exit 2
fi

mkdir -p .codex/audits
if [[ ! -f .codex/PROJECT-HISTORY.md ]]; then
  cat > .codex/PROJECT-HISTORY.md <<'EOF'
# Local Project History

Use this local-only file for verbose milestones, implementation notes, and completed-task history that should not clutter README.md.
EOF
fi

if [[ ! -f .codex/AUDIT-LOG.md ]]; then
  cat > .codex/AUDIT-LOG.md <<'EOF'
# Local Audit Log

Use this local-only file for operational notes from codex audit runs.
EOF
fi

if [[ "$MODE" == "staged" ]]; then
  CHANGED_FILES="$(git diff --cached --name-only)"
  DIFF_CONTENT="$(git diff --cached --no-color)"
  SCOPE_LABEL="staged diff"
else
  CHANGED_FILES="$(git diff --name-only)"
  DIFF_CONTENT="$(git diff --no-color)"
  SCOPE_LABEL="working tree diff"
fi

if [[ -z "${CHANGED_FILES}" ]]; then
  echo "codex:audit:batch INFO: no changed files in ${SCOPE_LABEL}; skipping audit."
  exit 0
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_PATH=".codex/audits/batch-audit-${TS}.txt"
PROMPT_PATH=".codex/audits/batch-audit-${TS}.prompt.txt"

{
  echo "You are a strict batch-change auditor for this repository."
  echo "Audit scope: ${SCOPE_LABEL}"
  echo
  echo "Goals:"
  echo "1) Security guardrails: auth/authz, CSRF, CORS, ownership checks, input validation, rate limiting."
  echo "2) Workflow guardrails: release/check scripts and required gates still enforced."
  echo "3) Documentation drift: README.md / PROJECT-OVERVIEW.md / AGENTS.md / PROJECT-SECURITY.md updated when behavior or process changed."
  echo "4) Contract drift: endpoint/schema/auth expectations changed without clear contract notes."
  echo "5) Clutter guardrail: keep README integration-focused; verbose milestone history should go to local-only context files."
  echo
  echo "Return exactly this plain-text format:"
  echo "AUDIT_STATUS: PASS|FAIL"
  echo "SEVERITY_COUNTS: critical=<n> high=<n> medium=<n> low=<n>"
  echo "REQUIRES_DOC_UPDATES: yes|no"
  echo "FINDINGS:"
  echo "- [severity][path-or-scope] concise issue | concise remediation"
  echo "- none"
  echo
  echo "If any critical/high finding exists, AUDIT_STATUS must be FAIL."
  echo
  echo "Changed files:"
  printf "%s\n" "${CHANGED_FILES}"
  echo
  echo "PROJECT CONTEXT FILE: AGENTS.md"
  sed -n '1,220p' AGENTS.md || true
  echo
  echo "PROJECT CONTEXT FILE: README.md"
  sed -n '1,260p' README.md || true
  echo
  echo "PROJECT CONTEXT FILE: PROJECT-OVERVIEW.md"
  sed -n '1,260p' PROJECT-OVERVIEW.md || true
  echo
  echo "PROJECT CONTEXT FILE: PROJECT-SECURITY.md"
  sed -n '1,260p' PROJECT-SECURITY.md || true
  echo
  echo "DIFF START"
  printf "%s\n" "${DIFF_CONTENT}"
  echo "DIFF END"
} > "${PROMPT_PATH}"

cat "${PROMPT_PATH}" | codex exec - -o "${REPORT_PATH}"

STATUS_LINE="$(grep -E '^AUDIT_STATUS:' "${REPORT_PATH}" | tail -n 1 || true)"
COUNTS_LINE="$(grep -E '^SEVERITY_COUNTS:' "${REPORT_PATH}" | tail -n 1 || true)"

echo "codex:audit:batch report: ${REPORT_PATH}"
[[ -n "${COUNTS_LINE}" ]] && echo "${COUNTS_LINE}"

{
  echo
  echo "## ${TS} (${SCOPE_LABEL})"
  echo "- report: ${REPORT_PATH}"
  [[ -n "${STATUS_LINE}" ]] && echo "- ${STATUS_LINE}"
  [[ -n "${COUNTS_LINE}" ]] && echo "- ${COUNTS_LINE}"
} >> .codex/AUDIT-LOG.md

if [[ "${STATUS_LINE}" == "AUDIT_STATUS: FAIL" ]]; then
  echo "codex:audit:batch FAIL: critical/high findings detected."
  if [[ "${SOFT_FAIL}" == "1" ]]; then
    echo "codex:audit:batch INFO: soft-fail mode enabled; continuing."
    exit 0
  fi
  exit 3
fi

echo "codex:audit:batch PASS"
