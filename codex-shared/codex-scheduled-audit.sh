#!/usr/bin/env bash
set -euo pipefail

DAYS="${1:-7}"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex:audit:repo WARN: codex CLI not found; skipping audit."
  exit 0
fi

mkdir -p .codex/audits
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_PATH=".codex/audits/scheduled-audit-${TS}.txt"
PROMPT_PATH=".codex/audits/scheduled-audit-${TS}.prompt.txt"

RECENT_LOG="$(git log --since="${DAYS} days ago" --date=short --pretty=format:'%h %ad %s' --name-only)"
LAST_COMMITS="$(git log -n 20 --date=short --pretty=format:'%h %ad %s' --name-only)"

{
  echo "You are a strict scheduled ecosystem-audit assistant for this repository."
  echo "Time window: last ${DAYS} days"
  echo
  echo "Check for:"
  echo "1) Security/process drift versus PROJECT-SECURITY.md."
  echo "2) Workflow drift versus release/check scripts and AGENTS.md."
  echo "3) Documentation drift between README.md and PROJECT-OVERVIEW.md."
  echo "4) Integration contract clarity for external repos."
  echo
  echo "Return exactly this plain-text format:"
  echo "AUDIT_STATUS: PASS|FAIL"
  echo "SEVERITY_COUNTS: critical=<n> high=<n> medium=<n> low=<n>"
  echo "TOP_ACTIONS:"
  echo "1. <most important action>"
  echo "2. <next action>"
  echo "3. <next action>"
  echo "FINDINGS:"
  echo "- [severity][scope] issue | remediation"
  echo "- none"
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
  echo "RECENT LOG (${DAYS} days)"
  printf "%s\n" "${RECENT_LOG}"
  echo
  echo "LAST 20 COMMITS"
  printf "%s\n" "${LAST_COMMITS}"
} > "${PROMPT_PATH}"

cat "${PROMPT_PATH}" | codex exec - -o "${REPORT_PATH}"
echo "codex:audit:repo report: ${REPORT_PATH}"
