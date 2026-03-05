#!/usr/bin/env bash
set -euo pipefail

BEGIN_MARKER="# WS_CLAUDE_AUDIT_CRON_BEGIN"
END_MARKER="# WS_CLAUDE_AUDIT_CRON_END"
EXPECTED_TOKEN="claude:audit:repo"

CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"

if [[ -z "${CURRENT_CRONTAB}" ]]; then
  echo "CLAUDE_CRON_STATUS: FAIL"
  echo "REASON: no user crontab entries found or crontab is unreadable."
  exit 1
fi

BLOCK="$(
  printf '%s\n' "${CURRENT_CRONTAB}" | awk -v begin="${BEGIN_MARKER}" -v end="${END_MARKER}" '
    $0 == begin { in_block=1; next }
    $0 == end { in_block=0; next }
    in_block == 1 { print }
  '
)"

if [[ -z "${BLOCK}" ]]; then
  echo "CLAUDE_CRON_STATUS: FAIL"
  echo "REASON: managed Claude cron block not found."
  echo "REMEDIATION: npm run claude:audit:cron:install -- 7"
  exit 1
fi

if ! grep -Fq "${EXPECTED_TOKEN}" <<< "${BLOCK}"; then
  echo "CLAUDE_CRON_STATUS: FAIL"
  echo "REASON: managed Claude cron block found, but expected audit command token is missing."
  echo "REMEDIATION: npm run claude:audit:cron:install -- 7"
  exit 1
fi

echo "CLAUDE_CRON_STATUS: PASS"
echo "ENTRY:"
printf '%s\n' "${BLOCK}"
