#!/usr/bin/env bash
set -euo pipefail

MODE="staged"
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
    *)
      echo "Usage: $0 [--staged|--working-tree]"
      exit 2
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "RISK_AUDIT: no"
  echo "REASON: not in a git repository"
  exit 1
fi

if [[ "${WS_FORCE_FULL_CODEX_AUDIT:-0}" == "1" ]]; then
  echo "RISK_AUDIT: yes"
  echo "REASON: WS_FORCE_FULL_CODEX_AUDIT=1"
  exit 0
fi

if [[ "${MODE}" == "staged" ]]; then
  CHANGED_FILES="$(git diff --cached --name-only)"
else
  CHANGED_FILES="$(git diff --name-only)"
fi

if [[ -z "${CHANGED_FILES}" ]]; then
  echo "RISK_AUDIT: no"
  echo "REASON: no changed files"
  exit 1
fi

# High-risk paths/extensions always trigger full audits.
DEFAULT_RISK_REGEX='(^|/)(AGENTS\.md|README\.md|PROJECT-OVERVIEW\.md|PROJECT_OVERVIEW\.md|PROJECT-SECURITY\.md|PROJECT_SECURITY\.md|package\.json|package-lock\.json|composer\.json|composer\.lock|pyproject\.toml|requirements.*\.txt|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock)$|^\.github/workflows/|^codex-shared/|^scripts/|^src/|^server/|^app/|^api/|^lib/|^packages/|^routes/|^controllers/|^middleware/|^db/|^database/|^migrations/|^config/|^public/character-api/|^public/rules-api/calc/|^public/rules-api/calc/schemas/|(^|/)(auth|oauth|session|csrf|cors|security|permission|ownership|schema|contract|endpoint|api)(/|_|-|\.)|(\.ts|\.tsx|\.js|\.jsx|\.mjs|\.cjs|\.php|\.py|\.rb|\.go|\.rs|\.java|\.kt|\.swift|\.cs|\.c|\.cc|\.cpp|\.h|\.hpp|\.sql|\.sh|\.bash|\.zsh|\.ps1|\.yaml|\.yml|\.toml|\.ini|\.conf|\.cfg|\.env)$'
RISK_REGEX="${WS_CODEX_RISK_REGEX:-$DEFAULT_RISK_REGEX}"

# Only these are considered low-risk enough to skip full subprocess audits.
DEFAULT_LOW_RISK_ONLY_REGEX='(^|/)(\.gitignore|\.gitattributes|LICENSE|LICENSE\.md|CHANGELOG\.md|.*\.md|.*\.txt|.*\.rst|.*\.adoc|.*\.png|.*\.jpg|.*\.jpeg|.*\.gif|.*\.webp|.*\.avif|.*\.svg|.*\.ico)$'
LOW_RISK_ONLY_REGEX="${WS_CODEX_LOW_RISK_ONLY_REGEX:-$DEFAULT_LOW_RISK_ONLY_REGEX}"

if command -v rg >/dev/null 2>&1; then
  MATCHES="$(printf "%s\n" "${CHANGED_FILES}" | rg -n -e "${RISK_REGEX}" || true)"
else
  MATCHES="$(printf "%s\n" "${CHANGED_FILES}" | grep -En "${RISK_REGEX}" || true)"
fi

if [[ -n "${MATCHES}" ]]; then
  echo "RISK_AUDIT: yes"
  echo "MATCHES:"
  printf "%s\n" "${MATCHES}"
  exit 0
fi

if command -v rg >/dev/null 2>&1; then
  NON_LOW="$(printf "%s\n" "${CHANGED_FILES}" | rg -n -v -e "${LOW_RISK_ONLY_REGEX}" || true)"
else
  NON_LOW="$(printf "%s\n" "${CHANGED_FILES}" | grep -En -v "${LOW_RISK_ONLY_REGEX}" || true)"
fi

if [[ -n "${NON_LOW}" ]]; then
  echo "RISK_AUDIT: yes"
  echo "REASON: fail-closed for non-allowlisted paths"
  echo "NON_LOW_RISK_PATHS:"
  printf "%s\n" "${NON_LOW}"
  exit 0
fi

echo "RISK_AUDIT: no"
echo "REASON: all changed files are low-risk allowlisted paths"
exit 1
