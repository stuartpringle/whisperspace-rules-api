#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
LOCK_DIR=".codex/audits/post-commit-worker.lock"
PID_FILE="${LOCK_DIR}/pid"
RUN_LOG=".codex/audits/post-commit-worker.log"
QUEUE_PATH=".codex/audits/post-commit-queue.tsv"

ensure_running=0
if [[ "${1:-}" == "--ensure-running" ]]; then
  ensure_running=1
fi

mkdir -p .codex/audits

recover_stale_lock() {
  if [[ ! -d "${LOCK_DIR}" ]]; then
    return 0
  fi

  if [[ -f "${PID_FILE}" ]]; then
    lock_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
    if [[ -n "${lock_pid}" ]] && kill -0 "${lock_pid}" 2>/dev/null; then
      return 0
    fi
  fi

  rm -f "${PID_FILE}" 2>/dev/null || true
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}

run_worker() {
  recover_stale_lock
  if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    return 0
  fi

  trap 'rm -f "${PID_FILE}"; rmdir "${LOCK_DIR}" 2>/dev/null || true' EXIT
  echo "$$" > "${PID_FILE}"

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
