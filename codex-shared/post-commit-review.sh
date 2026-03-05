#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "post-commit:review ERROR: not in a git repository."
  exit 2
fi

commit_hash="${1:-HEAD}"
if ! git cat-file -e "${commit_hash}^{commit}" 2>/dev/null; then
  echo "post-commit:review ERROR: commit not found: ${commit_hash}"
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "post-commit:review WARN: codex CLI not found; skipping commit ${commit_hash}"
  exit 0
fi

mkdir -p .codex/audits
if [[ ! -f .codex/AUDIT-LOG.md ]]; then
  cat > .codex/AUDIT-LOG.md <<'EOF'
# Local Audit Log

Use this local-only file for operational notes from codex audit runs.
EOF
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SHORT_COMMIT="$(git rev-parse --short "${commit_hash}")"
REPORT_PATH=".codex/audits/post-commit-audit-${SHORT_COMMIT}-${TS}.txt"
PROMPT_PATH=".codex/audits/post-commit-audit-${SHORT_COMMIT}-${TS}.prompt.txt"
TIMEOUT_SEC="${WS_POST_COMMIT_AUDIT_TIMEOUT_SEC:-900}"

changed_files="$(git show --pretty='' --name-only "${commit_hash}" | sed '/^$/d')"
if [[ -z "${changed_files}" ]]; then
  echo "post-commit:review INFO: no changed files in ${commit_hash}; skipping."
  exit 0
fi

{
  echo "You are a strict post-commit code-review auditor for this repository."
  echo "Audit scope: commit ${commit_hash}"
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
  printf '%s\n' "${changed_files}"
  echo
  echo "PROJECT CONTEXT FILE: AGENTS.md"
  sed -n '1,220p' AGENTS.md 2>/dev/null || true
  echo
  echo "PROJECT CONTEXT FILE: README.md"
  sed -n '1,260p' README.md 2>/dev/null || true
  echo
  echo "PROJECT CONTEXT FILE: PROJECT-OVERVIEW.md"
  sed -n '1,260p' PROJECT-OVERVIEW.md 2>/dev/null || true
  echo
  echo "PROJECT CONTEXT FILE: PROJECT-SECURITY.md"
  sed -n '1,260p' PROJECT-SECURITY.md 2>/dev/null || true
  echo
  echo "COMMIT DIFF START"
  git show --no-color --stat --patch "${commit_hash}"
  echo "COMMIT DIFF END"
} > "${PROMPT_PATH}"

if [[ "${TIMEOUT_SEC}" =~ ^[0-9]+$ ]] && [[ "${TIMEOUT_SEC}" -gt 0 ]] && command -v timeout >/dev/null 2>&1; then
  if ! cat "${PROMPT_PATH}" | timeout "${TIMEOUT_SEC}" codex exec - -o "${REPORT_PATH}"; then
    cat > "${REPORT_PATH}" <<EOF
AUDIT_STATUS: FAIL
SEVERITY_COUNTS: critical=0 high=0 medium=1 low=0
REQUIRES_DOC_UPDATES: no
FINDINGS:
- [medium][post-commit-review] codex post-commit review timed out or failed for commit ${commit_hash} | rerun: npm run codex:audit:post-commit -- ${commit_hash}
EOF
  fi
else
  if ! cat "${PROMPT_PATH}" | codex exec - -o "${REPORT_PATH}"; then
    cat > "${REPORT_PATH}" <<EOF
AUDIT_STATUS: FAIL
SEVERITY_COUNTS: critical=0 high=0 medium=1 low=0
REQUIRES_DOC_UPDATES: no
FINDINGS:
- [medium][post-commit-review] codex post-commit review failed for commit ${commit_hash} | rerun: npm run codex:audit:post-commit -- ${commit_hash}
EOF
  fi
fi

status_line="$(grep -E '^AUDIT_STATUS:' "${REPORT_PATH}" | tail -n 1 || true)"
counts_line="$(grep -E '^SEVERITY_COUNTS:' "${REPORT_PATH}" | tail -n 1 || true)"

echo "post-commit:review report: ${REPORT_PATH}"
[[ -n "${counts_line}" ]] && echo "${counts_line}"

{
  echo
  echo "## ${TS} (post-commit ${SHORT_COMMIT})"
  echo "- report: ${REPORT_PATH}"
  [[ -n "${status_line}" ]] && echo "- ${status_line}"
  [[ -n "${counts_line}" ]] && echo "- ${counts_line}"
} >> .codex/AUDIT-LOG.md

if [[ "${status_line}" == "AUDIT_STATUS: FAIL" ]]; then
  echo "post-commit:review WARN: commit ${commit_hash} has high/critical findings."
fi
