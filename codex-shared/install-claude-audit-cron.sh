#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ecosystem-paths.sh"
LOG_PATH="${WS_AUDIT_ARTIFACTS_DIR}/claude-scheduled-audit-cron.log"

SCHEDULE="${WS_CLAUDE_AUDIT_CRON_SCHEDULE:-17 3 * * *}"
DAYS="${1:-${WS_CLAUDE_AUDIT_DAYS:-7}}"

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: days must be an integer, got: ${DAYS}"
  exit 2
fi

if [[ "${SCHEDULE}" == *$'\n'* || "${SCHEDULE}" == *$'\r'* ]]; then
  echo "ERROR: schedule must not contain newlines."
  exit 2
fi

IFS=' ' read -r -a SCHEDULE_PARTS <<< "${SCHEDULE}"
if [[ "${#SCHEDULE_PARTS[@]}" -ne 5 ]]; then
  echo "ERROR: schedule must have exactly 5 cron fields."
  exit 2
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not found in PATH."
  exit 2
fi
NPM_BIN="$(command -v npm)"

mkdir -p "${WS_AUDIT_ARTIFACTS_DIR}"

CRON_CMD="cd ${WS_POLICY_ROOT} && bash ${WS_SHARED_ROOT}/claude-scheduled-audit.sh ${DAYS} >> ${LOG_PATH} 2>&1"
BEGIN_MARKER="# WS_CLAUDE_AUDIT_CRON_BEGIN"
END_MARKER="# WS_CLAUDE_AUDIT_CRON_END"

CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"

STRIPPED_CRONTAB="$(
  printf '%s\n' "${CURRENT_CRONTAB}" | awk -v begin="${BEGIN_MARKER}" -v end="${END_MARKER}" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    skip == 0 { print }
  '
)"

NEW_BLOCK="$(cat <<EOF
${BEGIN_MARKER}
${SCHEDULE} ${CRON_CMD}
${END_MARKER}
EOF
)"

if [[ -n "${STRIPPED_CRONTAB}" ]]; then
  UPDATED_CRONTAB="${STRIPPED_CRONTAB}"$'\n'"${NEW_BLOCK}"
else
  UPDATED_CRONTAB="${NEW_BLOCK}"
fi

printf '%s\n' "${UPDATED_CRONTAB}" | crontab -

echo "Installed Claude scheduled audit cron entry."
echo "Schedule: ${SCHEDULE}"
echo "Command: ${CRON_CMD}"
echo "Log file: ${LOG_PATH}"
