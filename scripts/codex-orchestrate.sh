#!/usr/bin/env bash
set -euo pipefail

MAX_AGENTS=4
TASKS_FILE=""
OUTPUT_ROOT=".codex/orchestrator"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/codex-orchestrate.sh --tasks <tasks-file> [--max-agents <n>] [--output-dir <dir>]

Tasks file format:
  - One task prompt per line.
  - Empty lines and lines starting with # are ignored.
  - Markdown list prefixes "- " are allowed and stripped.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks)
      TASKS_FILE="${2:-}"
      shift 2
      ;;
    --max-agents)
      MAX_AGENTS="${2:-4}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_ROOT="${2:-.codex/orchestrator}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${TASKS_FILE}" || ! -f "${TASKS_FILE}" ]]; then
  echo "ERROR: --tasks file is required and must exist."
  usage
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI is not installed."
  exit 5
fi

if ! [[ "${MAX_AGENTS}" =~ ^[0-9]+$ ]] || [[ "${MAX_AGENTS}" -lt 1 ]]; then
  echo "ERROR: --max-agents must be a positive integer."
  exit 2
fi

mapfile -t RAW_LINES < "${TASKS_FILE}"
declare -a TASKS=()
for line in "${RAW_LINES[@]}"; do
  trimmed="$(echo "${line}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -z "${trimmed}" ]] && continue
  [[ "${trimmed}" =~ ^# ]] && continue
  trimmed="${trimmed#- }"
  [[ -z "${trimmed}" ]] && continue
  TASKS+=( "${trimmed}" )
done

if [[ "${#TASKS[@]}" -eq 0 ]]; then
  echo "ERROR: no runnable tasks found in ${TASKS_FILE}."
  exit 2
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${OUTPUT_ROOT}/run-${TS}"
mkdir -p "${RUN_DIR}"

echo "RUN_DIR: ${RUN_DIR}"
echo "MAX_AGENTS: ${MAX_AGENTS}"
echo "TASK_COUNT: ${#TASKS[@]}"

running_jobs() {
  jobs -pr | wc -l | tr -d ' '
}

for i in "${!TASKS[@]}"; do
  idx=$((i + 1))
  prompt="${TASKS[$i]}"
  out="${RUN_DIR}/agent-$(printf '%02d' "${idx}").txt"
  rc="${RUN_DIR}/agent-$(printf '%02d' "${idx}").rc"
  prompt_file="${RUN_DIR}/agent-$(printf '%02d' "${idx}").prompt.txt"

  printf '%s\n' "${prompt}" > "${prompt_file}"
  echo "START agent-${idx}: ${prompt}"

  (
    set +e
    codex exec "${prompt}" --json -o "${out}"
    ec=$?
    echo "${ec}" > "${rc}"
    exit "${ec}"
  ) &

  while [[ "$(running_jobs)" -ge "${MAX_AGENTS}" ]]; do
    sleep 0.2
  done
done

wait || true

summary="${RUN_DIR}/summary.md"
{
  echo "# Codex Orchestrator Run"
  echo
  echo "- Timestamp (UTC): ${TS}"
  echo "- Max agents: ${MAX_AGENTS}"
  echo "- Task count: ${#TASKS[@]}"
  echo
  echo "## Results"
} > "${summary}"

fail_count=0
for i in "${!TASKS[@]}"; do
  idx=$((i + 1))
  out="${RUN_DIR}/agent-$(printf '%02d' "${idx}").txt"
  rc="${RUN_DIR}/agent-$(printf '%02d' "${idx}").rc"
  prompt="${TASKS[$i]}"
  code="NA"
  [[ -f "${rc}" ]] && code="$(cat "${rc}")"

  if [[ "${code}" != "0" ]]; then
    fail_count=$((fail_count + 1))
  fi

  {
    echo
    echo "### agent-${idx}"
    echo "- exit_code: ${code}"
    echo "- prompt: ${prompt}"
    echo "- output: ${out}"
  } >> "${summary}"
done

echo "FAILURES: ${fail_count}"
echo "SUMMARY: ${summary}"
if [[ "${fail_count}" -gt 0 ]]; then
  exit 3
fi

exit 0
