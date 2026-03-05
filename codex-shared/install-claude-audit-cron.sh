#!/usr/bin/env bash
set -euo pipefail

ROOT="/hdd/sites/stuartpringle"
RULES_API_REPO="${ROOT}/whisperspace-rules-api"
LOG_PATH="${RULES_API_REPO}/.codex/audits/claude-scheduled-audit-cron.log"

SCHEDULE="${WS_CLAUDE_AUDIT_CRON_SCHEDULE:-17 3 * * *}"
DAYS="${1:-${WS_CLAUDE_AUDIT_DAYS:-7}}"

if ! [[ "${DAYS}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: days must be an integer, got: ${DAYS}"
  exit 2
fi

mkdir -p "${RULES_API_REPO}/.codex/audits"

CRON_CMD="cd ${RULES_API_REPO} && npm run claude:audit:repo -- ${DAYS} >> ${LOG_PATH} 2>&1"
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
