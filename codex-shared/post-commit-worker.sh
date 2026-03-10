#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ecosystem-paths.sh"
ROOT_SHARED="${WS_SHARED_ROOT}"
LOCK_DIR=".codex/audits/post-commit-worker.lock"
PID_FILE="${LOCK_DIR}/pid"
START_FILE="${LOCK_DIR}/starttime"
RUN_LOG=".codex/audits/post-commit-worker.log"
QUEUE_PATH=".codex/audits/post-commit-queue.tsv"

ensure_running=0
if [[ "${1:-}" == "--ensure-running" ]]; then
  ensure_running=1
fi

mkdir -p .codex/audits

read_proc_start_time() {
  local pid="${1:-}"
  local stat_path="/proc/${pid}/stat"
  local stat_line
  if [[ -z "${pid}" || ! -r "${stat_path}" ]]; then
    return 1
  fi

  stat_line="$(cat "${stat_path}" 2>/dev/null || true)"
  if [[ -z "${stat_line}" ]]; then
    return 1
  fi

  printf '%s\n' "${stat_line}" | awk '{print $22}'
}

proc_cmdline_looks_like_worker() {
  local pid="${1:-}"
  local cmdline_path="/proc/${pid}/cmdline"
  local cmdline
  if [[ -z "${pid}" || ! -r "${cmdline_path}" ]]; then
    return 1
  fi

  cmdline="$(tr '\0' ' ' < "${cmdline_path}" 2>/dev/null || true)"
  [[ "${cmdline}" == *"post-commit-worker.sh"* ]]
}

lock_owner_is_current_worker() {
  local lock_pid="${1:-}"
  local recorded_start="${2:-}"
  local live_start

  if [[ -z "${lock_pid}" ]] || ! kill -0 "${lock_pid}" 2>/dev/null; then
    return 1
  fi

  if ! proc_cmdline_looks_like_worker "${lock_pid}"; then
    return 1
  fi

  if [[ -n "${recorded_start}" ]]; then
    live_start="$(read_proc_start_time "${lock_pid}" || true)"
    if [[ -z "${live_start}" || "${live_start}" != "${recorded_start}" ]]; then
      return 1
    fi
  fi

  return 0
}

recover_stale_lock() {
  local lock_pid=""
  local recorded_start=""

  if [[ ! -d "${LOCK_DIR}" ]]; then
    return 0
  fi

  if [[ -f "${PID_FILE}" ]]; then
    lock_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  fi
  if [[ -f "${START_FILE}" ]]; then
    recorded_start="$(cat "${START_FILE}" 2>/dev/null || true)"
  fi

  if lock_owner_is_current_worker "${lock_pid}" "${recorded_start}"; then
      return 0
  fi

  rm -f "${PID_FILE}" "${START_FILE}" 2>/dev/null || true
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}

run_worker() {
  recover_stale_lock
  if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    return 0
  fi

  trap 'rm -f "${PID_FILE}" "${START_FILE}"; rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT
  echo "$$" > "${PID_FILE}"
  read_proc_start_time "$$" > "${START_FILE}" 2>/dev/null || true

  while [[ -s "${QUEUE_PATH}" ]]; do
    line="$(head -n 1 "${QUEUE_PATH}" || true)"
    if [[ -z "${line}" ]]; then
      break
    fi

    tail -n +2 "${QUEUE_PATH}" > "${QUEUE_PATH}.tmp" || true
    mv "${QUEUE_PATH}.tmp" "${QUEUE_PATH}"

    commit_hash="$(printf '%s' "${line}" | awk -F '\t' '{print $2}')"
    if [[ -z "${commit_hash}" ]]; then
      continue
    fi

    {
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] START commit=${commit_hash}"
      bash "${ROOT_SHARED}/post-commit-review.sh" "${commit_hash}"
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] END commit=${commit_hash}"
    } >> "${RUN_LOG}" 2>&1
  done
}

if [[ "${ensure_running}" -eq 1 ]]; then
  nohup bash "${ROOT_SHARED}/post-commit-worker.sh" >/dev/null 2>&1 &
  exit 0
fi

run_worker
