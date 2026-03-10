#!/usr/bin/env bash
set -euo pipefail

WS_ECOSYSTEM_ROOT="${WS_ECOSYSTEM_ROOT:-/hdd/sites/whisperspace}"
ROOT_PUBLISH_SCRIPT="${WS_ECOSYSTEM_ROOT}/scripts/rules-publish.sh"

if [[ ! -f "${ROOT_PUBLISH_SCRIPT}" ]]; then
  echo "ERROR: root workspace publish script not found: ${ROOT_PUBLISH_SCRIPT}" >&2
  exit 2
fi

cd "${WS_ECOSYSTEM_ROOT}"
exec bash "${ROOT_PUBLISH_SCRIPT}" "$@"
