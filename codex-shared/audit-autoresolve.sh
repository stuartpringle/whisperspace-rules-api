#!/usr/bin/env bash
set -euo pipefail

WINDOW=3
declare -a RESOLVE_KEYS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --window)
      WINDOW="${2:-3}"
      shift 2
      ;;
    --resolve-key)
      RESOLVE_KEYS+=( "${2:-}" )
      shift 2
      ;;
    *)
      echo "Usage: $0 [--window <n>] [--resolve-key <severity|scope|issue>]..."
      exit 2
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "audit:autoresolve ERROR: not in a git repository."
  exit 2
fi

AUDIT_DIR=".codex/audits"
AUDIT_LOG=".codex/AUDIT-LOG.md"
mkdir -p "${AUDIT_DIR}" .codex
touch "${AUDIT_LOG}"

tmp_known="$(mktemp)"
tmp_open="$(mktemp)"
tmp_resolved="$(mktemp)"
tmp_candidates="$(mktemp)"
trap 'rm -f "${tmp_known}" "${tmp_open}" "${tmp_resolved}" "${tmp_candidates}"' EXIT

shopt -s nullglob
batch_reports=( "${AUDIT_DIR}"/batch-audit-*.txt )
shopt -u nullglob

if [[ ${#batch_reports[@]} -eq 0 ]]; then
  echo "AUTORESOLVE_CANDIDATES: 0"
  exit 0
fi

for report in "${batch_reports[@]}"; do
  [[ "${report}" == *.prompt.txt ]] && continue
  awk '
    match($0,/^- \[(critical|high)\]\[([^]]+)\] (.*) \| /,a){
      print a[1] "|" a[2] "|" a[3]
    }
  ' "${report}" >> "${tmp_known}"
done
sort -u -o "${tmp_known}" "${tmp_known}"

for report in "${batch_reports[@]}"; do
  [[ "${report}" == *.prompt.txt ]] && continue
  echo "${report}"
done | sort | tail -n "${WINDOW}" | while read -r report; do
  awk '
    match($0,/^- \[(critical|high)\]\[([^]]+)\] (.*) \| /,a){
      print a[1] "|" a[2] "|" a[3]
    }
  ' "${report}" >> "${tmp_open}"
done
sort -u -o "${tmp_open}" "${tmp_open}"

awk '
  {
    l=tolower($0)
    if (index(l, "resolved:") > 0) {
      sub(/^[[:space:]-]*/, "", $0)
      sub(/^[Rr][Ee][Ss][Oo][Ll][Vv][Ee][Dd]:[[:space:]]*/, "", $0)
      if (length($0) > 0) print $0
    }
  }
' "${AUDIT_LOG}" | sort -u > "${tmp_resolved}"

comm -23 "${tmp_known}" "${tmp_open}" | comm -23 - "${tmp_resolved}" > "${tmp_candidates}"

count="$(wc -l < "${tmp_candidates}" | tr -d ' ')"
echo "AUTORESOLVE_CANDIDATES: ${count}"
if [[ "${count}" -gt 0 ]]; then
  echo "AUTORESOLVE_FINDINGS:"
  sed 's/^/- /' "${tmp_candidates}"
fi

if [[ ${#RESOLVE_KEYS[@]} -eq 0 ]]; then
  exit 0
fi

resolved_count=0
ts="$(date -u +%Y%m%dT%H%M%SZ)"
{
  echo
  echo "## ${ts} (manual resolve via audit-autoresolve)"
  for key in "${RESOLVE_KEYS[@]}"; do
    if grep -Fqx "${key}" "${tmp_candidates}"; then
      echo "- RESOLVED: ${key}"
      resolved_count=$((resolved_count + 1))
    else
      echo "- NOTE: resolve key not eligible (missing from candidates): ${key}"
    fi
  done
} >> "${AUDIT_LOG}"

echo "AUTORESOLVE_APPLIED: ${resolved_count}"
