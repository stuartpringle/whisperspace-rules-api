#!/usr/bin/env bash
set -euo pipefail

exec bash /hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/post-commit-review.sh "$@"
