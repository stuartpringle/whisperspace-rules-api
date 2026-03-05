#!/usr/bin/env bash
# WS_CODEX_MANAGED_PRECOMMIT
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
USER_HOOK_PATH="$(git rev-parse --git-path hooks)/pre-commit.user"
BYPASS_LOG_PATH=".codex/BYPASS-LOG.tsv"

has_pattern() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q "${pattern}" "${file}" 2>/dev/null
  else
    grep -q "${pattern}" "${file}" 2>/dev/null
  fi
}

run_user_hook() {
  if [[ -x "${USER_HOOK_PATH}" ]]; then
    # Skip legacy managed hooks to prevent recursive audit loops.
    if has_pattern "WS_CODEX_MANAGED_PRECOMMIT|codex:audit:batch" "${USER_HOOK_PATH}"; then
      echo "[pre-commit] skipping recursive legacy managed user hook: ${USER_HOOK_PATH}"
      return 0
    fi
    echo "[pre-commit] running preserved user hook: ${USER_HOOK_PATH}"
    "${USER_HOOK_PATH}"
  fi
}

append_bypass_log() {
  local risk_mode="$1"
  local reason="${WS_BYPASS_REASON:-}"
  local ts_iso ts_epoch branch head_short staged_files

  if [[ -z "${reason}" ]]; then
    echo "[pre-commit] emergency bypass requires WS_BYPASS_REASON with a concise justification."
    exit 10
  fi

  mkdir -p .codex
  if [[ ! -f "${BYPASS_LOG_PATH}" ]]; then
    echo "# epoch_utc\tiso_utc\tbranch\thead\trisk_mode\treason\tstaged_files" > "${BYPASS_LOG_PATH}"
  fi

  ts_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ts_epoch="$(date -u +%s)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
  head_short="$(git rev-parse --short HEAD 2>/dev/null || echo none)"
  staged_files="$(git diff --cached --name-only | tr '\n' ';' | sed 's/;$//')"

  reason="${reason//$'\t'/ }"
  reason="${reason//$'\n'/ }"
  reason="${reason//$'\r'/ }"
  reason="${reason//\\/\\\\}"
  staged_files="${staged_files//$'\t'/ }"
  staged_files="${staged_files//$'\n'/ }"
  staged_files="${staged_files//$'\r'/ }"
  staged_files="${staged_files//\\/\\\\}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${ts_epoch}" "${ts_iso}" "${branch}" "${head_short}" "${risk_mode}" "${reason}" "${staged_files}" >> "${BYPASS_LOG_PATH}"
  echo "[pre-commit] bypass logged: ${BYPASS_LOG_PATH}"
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

run_user_hook

if [[ -z "$(git diff --cached --name-only)" ]]; then
  exit 0
fi

echo "[pre-commit] running fast staged-diff checks"
git diff --cached --check --no-color

run_full_codex_audit=0
skip_codex_subprocess=0
risk_output=""
risk_status=0
if risk_output="$(bash "${ROOT_SHARED}/risk-trigger.sh" --staged 2>&1)"; then
  risk_status=0
else
  risk_status=$?
fi

if [[ "${risk_status}" -eq 0 ]]; then
  if grep -q '^RISK_AUDIT: yes' <<< "${risk_output}"; then
    run_full_codex_audit=1
  fi
elif [[ "${risk_status}" -eq 1 ]]; then
  run_full_codex_audit=0
else
  echo "[pre-commit] risk trigger failed (status=${risk_status}); failing closed to full codex audits"
  [[ -n "${risk_output}" ]] && echo "${risk_output}"
  run_full_codex_audit=1
fi

if [[ "${WS_SKIP_CODEX_AUDIT:-0}" == "1" ]]; then
  if [[ "${WS_MANUAL_AUDIT_ACK:-}" != "I_RAN_CODEX_AUDITS" ]]; then
    echo "[pre-commit] WS_SKIP_CODEX_AUDIT=1 requires explicit manual audit acknowledgment."
    echo "[pre-commit] Run: npm run codex:audit:batch && npm run codex:audit:docs"
    echo "[pre-commit] Then re-run with: WS_MANUAL_AUDIT_ACK=I_RAN_CODEX_AUDITS"
    exit 9
  fi

  if [[ "${run_full_codex_audit}" == "1" ]]; then
    if [[ "${WS_ALLOW_RISKY_SKIP:-0}" == "1" ]]; then
      echo "[pre-commit] emergency bypass enabled for risk-triggered change set (WS_ALLOW_RISKY_SKIP=1)"
      skip_codex_subprocess=1
      append_bypass_log "risk"
    else
      echo "[pre-commit] WS_SKIP_CODEX_AUDIT=1 ignored for risk-triggered changes (set WS_ALLOW_RISKY_SKIP=1 for explicit emergency bypass)"
    fi
  else
    echo "[pre-commit] codex subprocess audits bypassed for low-risk change set (WS_SKIP_CODEX_AUDIT=1 + manual audit ack)"
    skip_codex_subprocess=1
    append_bypass_log "low"
  fi
fi

if [[ "${skip_codex_subprocess}" == "1" ]]; then
  echo "[pre-commit] full codex audits skipped (low-risk change set)"
  [[ -n "${risk_output}" ]] && echo "${risk_output}"
elif [[ "${run_full_codex_audit}" == "1" ]]; then
  echo "[pre-commit] full codex audits required (risk-triggered)"
  echo "${risk_output}"
  if [[ -f package.json ]] && has_pattern '"codex:audit:batch"' package.json; then
    echo "[pre-commit] running npm run codex:audit:batch"
    npm run codex:audit:batch
  else
    bash "${ROOT_SHARED}/codex-batch-audit.sh" --staged
  fi

  echo "[pre-commit] running documentation audit"
  bash "${ROOT_SHARED}/codex-docs-audit.sh"
else
  echo "[pre-commit] full codex audits skipped (low-risk change set)"
  echo "${risk_output}"
fi

echo "[pre-commit] checking unresolved audit findings"
bash "${ROOT_SHARED}/audit-status.sh"
