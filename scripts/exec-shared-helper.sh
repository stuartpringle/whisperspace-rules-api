#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_NAME="${1:-}"
shift || true

if [[ -z "${HELPER_NAME}" ]]; then
  echo "Usage: $0 <shared-helper-name> [args...]" >&2
  exit 2
fi

for candidate in \
  "${WS_SHARED_ROOT:-}" \
  "$(cd "${SCRIPT_DIR}/../codex-shared" && pwd)" \
  "${WS_ECOSYSTEM_ROOT:-/hdd/sites/whisperspace}/codex-shared" \
  "/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
do
  if [[ -n "${candidate}" && -f "${candidate}/${HELPER_NAME}" ]]; then
    exec bash "${candidate}/${HELPER_NAME}" "$@"
  fi
done

echo "Unable to locate shared helper: ${HELPER_NAME}" >&2
exit 1
