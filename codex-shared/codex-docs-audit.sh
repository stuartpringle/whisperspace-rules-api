#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "codex:audit:docs ERROR: not in a git repository."
  exit 2
fi

if [[ -z "$(git diff --cached --name-only)" ]]; then
  echo "codex:audit:docs INFO: no staged changes; skipping."
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  if [[ "${WS_SKIP_CODEX_AUDIT:-0}" == "1" ]]; then
    echo "codex:audit:docs WARN: codex CLI not found; bypassed via WS_SKIP_CODEX_AUDIT=1."
    exit 0
  fi
  echo "codex:audit:docs ERROR: codex CLI not found."
  echo "codex:audit:docs Set WS_SKIP_CODEX_AUDIT=1 for explicit temporary bypass."
  exit 5
fi

mkdir -p .codex/audits
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_PATH=".codex/audits/docs-audit-${TS}.txt"

{
  echo "You are a strict documentation drift auditor."
  echo "Review staged changes and decide whether documentation updates are required."
  echo
  echo "Focus areas:"
  echo "1) README integration contract accuracy."
  echo "2) Endpoint/schema/auth/build/publish docs alignment."
  echo "3) Missing docs for API surface changes."
  echo
  echo "Return exactly:"
  echo "DOC_AUDIT_STATUS: PASS|FAIL"
  echo "DOC_REQUIRED: yes|no"
  echo "DOC_FINDINGS:"
  echo "- [severity][path] issue | required doc change"
  echo "- none"
  echo
  echo "If docs are required and not staged, return DOC_AUDIT_STATUS: FAIL."
  echo
  echo "STAGED FILES:"
  git diff --cached --name-only
  echo
  echo "README.md (if present):"
  sed -n '1,260p' README.md 2>/dev/null || true
  echo
  echo "PROJECT-OVERVIEW.md (if present):"
  sed -n '1,260p' PROJECT-OVERVIEW.md 2>/dev/null || true
  echo
  echo "PROJECT-SECURITY.md (if present):"
  sed -n '1,260p' PROJECT-SECURITY.md 2>/dev/null || true
  echo
  echo "DIFF START"
  git diff --cached --no-color
  echo "DIFF END"
} | codex exec - -o "${REPORT_PATH}"

echo "codex:audit:docs report: ${REPORT_PATH}"
if grep -q '^DOC_AUDIT_STATUS: FAIL' "${REPORT_PATH}"; then
  echo "codex:audit:docs FAIL: documentation updates required."
  cat "${REPORT_PATH}"
  exit 4
fi

echo "codex:audit:docs PASS"
