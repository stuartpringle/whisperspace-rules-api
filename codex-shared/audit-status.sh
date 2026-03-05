#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "audit:status ERROR: not in a git repository."
  exit 2
fi

AUDIT_DIR=".codex/audits"
AUDIT_LOG=".codex/AUDIT-LOG.md"

if [[ ! -d "${AUDIT_DIR}" ]]; then
  echo "AUDIT_STATUS: PASS"
  echo "UNRESOLVED_HIGH_CRITICAL: 0"
  echo "UNRESOLVED_OLDER_THAN_ONE_COMMIT: 0"
  exit 0
fi

HEAD_TS="$(git log -1 --format=%ct 2>/dev/null || echo 0)"
PREV_TS="$(git log -1 --skip=1 --format=%ct 2>/dev/null || echo 0)"

if [[ -z "${HEAD_TS}" || "${HEAD_TS}" == "" ]]; then
  HEAD_TS=0
fi
if [[ -z "${PREV_TS}" || "${PREV_TS}" == "" ]]; then
  PREV_TS=0
fi

tmp_findings="$(mktemp)"
tmp_resolved="$(mktemp)"
trap 'rm -f "${tmp_findings}" "${tmp_resolved}"' EXIT

shopt -s nullglob
reports=( "${AUDIT_DIR}"/*.txt )
shopt -u nullglob

for report in "${reports[@]}"; do
  base="$(basename "${report}")"
  if [[ "${base}" == *.prompt.txt ]]; then
    continue
  fi

  report_ts_iso="$(sed -n 's/.*-\([0-9]\{8\}T[0-9]\{6\}Z\)\.txt$/\1/p' <<< "${base}")"
  report_ts_epoch=0
  if [[ -n "${report_ts_iso}" ]]; then
    report_ts_epoch="$(date -u -d "${report_ts_iso}" +%s 2>/dev/null || echo 0)"
  fi

  awk -v r="${report}" -v e="${report_ts_epoch}" '
    match($0,/^- \[(critical|high)\]\[([^]]+)\] (.*) \| /,a){
      sev=a[1]
      scope=a[2]
      issue=a[3]
      key=sev "|" scope "|" issue
      print key "\t" r "\t" e
    }
  ' "${report}" >> "${tmp_findings}"
done

if [[ -f "${AUDIT_LOG}" ]]; then
  awk '
    {
      l=tolower($0)
      if (index(l, "resolved:") > 0) {
        sub(/^[[:space:]-]*/, "", $0)
        sub(/^[Rr][Ee][Ss][Oo][Ll][Vv][Ee][Dd]:[[:space:]]*/, "", $0)
        if (length($0) > 0) print $0
      }
    }
  ' "${AUDIT_LOG}" > "${tmp_resolved}"
fi

if [[ ! -s "${tmp_findings}" ]]; then
  echo "AUDIT_STATUS: PASS"
  echo "UNRESOLVED_HIGH_CRITICAL: 0"
  echo "UNRESOLVED_OLDER_THAN_ONE_COMMIT: 0"
  exit 0
fi

summary_tmp="$(mktemp)"
trap 'rm -f "${tmp_findings}" "${tmp_resolved}" "${summary_tmp}"' EXIT

awk -F '\t' '
  {
    key=$1
    report=$2
    ts=$3+0
    count[key]++
    if (!(key in first_ts) || ts < first_ts[key]) first_ts[key]=ts
    if (!(key in last_ts) || ts > last_ts[key]) last_ts[key]=ts
    last_report[key]=report
  }
  END {
    for (k in count) {
      print k "\t" count[k] "\t" first_ts[k] "\t" last_ts[k] "\t" last_report[k]
    }
  }
' "${tmp_findings}" > "${summary_tmp}"

unresolved_total=0
unresolved_older=0
declare -a unresolved_lines=()
declare -a unresolved_older_lines=()

while IFS=$'\t' read -r key count first_ts last_ts last_report; do
  [[ -z "${key}" ]] && continue

  if [[ -s "${tmp_resolved}" ]] && grep -Fqx "${key}" "${tmp_resolved}"; then
    continue
  fi

  unresolved_total=$((unresolved_total + 1))
  unresolved_lines+=( "${key} | occurrences=${count} | latest=${last_report}" )

  if [[ "${PREV_TS}" -gt 0 && "${first_ts}" -gt 0 && "${first_ts}" -le "${PREV_TS}" ]]; then
    unresolved_older=$((unresolved_older + 1))
    unresolved_older_lines+=( "${key} | first_seen_epoch=${first_ts} | latest=${last_report}" )
  fi
done < "${summary_tmp}"

if [[ "${unresolved_older}" -gt 0 ]]; then
  echo "AUDIT_STATUS: FAIL"
elif [[ "${unresolved_total}" -gt 0 ]]; then
  echo "AUDIT_STATUS: WARN"
else
  echo "AUDIT_STATUS: PASS"
fi

echo "UNRESOLVED_HIGH_CRITICAL: ${unresolved_total}"
echo "UNRESOLVED_OLDER_THAN_ONE_COMMIT: ${unresolved_older}"
echo "HEAD_COMMIT_EPOCH: ${HEAD_TS}"
echo "PREVIOUS_COMMIT_EPOCH: ${PREV_TS}"

if [[ "${unresolved_total}" -gt 0 ]]; then
  echo "UNRESOLVED_FINDINGS:"
  for line in "${unresolved_lines[@]}"; do
    echo "- ${line}"
  done
fi

if [[ "${unresolved_older}" -gt 0 ]]; then
  echo "BLOCKING_FINDINGS:"
  for line in "${unresolved_older_lines[@]}"; do
    echo "- ${line}"
  done
fi

if [[ "${unresolved_older}" -gt 0 ]]; then
  echo "audit:status FAIL: unresolved high/critical findings older than one commit."
  exit 7
fi

echo "audit:status OK"
