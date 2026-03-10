#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ecosystem-paths.sh"

mapfile -t WS_REPOS < <(ws_all_repo_paths)
