#!/usr/bin/env bash
set -euo pipefail

REPOS=(
  "/hdd/sites/stuartpringle/whisperspace"
  "/hdd/sites/stuartpringle/whisperspace-character-builder"
  "/hdd/sites/stuartpringle/whisperspace-developer"
  "/hdd/sites/stuartpringle/whisperspace-docs"
  "/hdd/sites/stuartpringle/whisperspace-obr-extension"
  "/hdd/sites/stuartpringle/whisperspace-obr-gm"
  "/hdd/sites/stuartpringle/whisperspace-obr-rules-extension"
  "/hdd/sites/stuartpringle/whisperspace-obr-sheet"
  "/hdd/sites/stuartpringle/whisperspace-rules-api"
  "/hdd/sites/stuartpringle/whisperspace-rules-parser"
  "/hdd/sites/stuartpringle/whisperspace-sdk"
)

for repo in "${REPOS[@]}"; do
  if [[ ! -d "${repo}" ]]; then
    echo "WARN: missing repo path, skipping: ${repo}"
    continue
  fi

  if ! git -C "${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "WARN: not a git repo, skipping: ${repo}"
    continue
  fi

  hooks_dir_rel="$(git -C "${repo}" rev-parse --git-path hooks)"
  if [[ "${hooks_dir_rel}" = /* ]]; then
    hooks_dir="${hooks_dir_rel}"
  else
    hooks_dir="${repo}/${hooks_dir_rel}"
  fi
  hook_path="${hooks_dir}/pre-commit"
  backup_hook_path="${hooks_dir}/pre-commit.user"
  mkdir -p "${hooks_dir}"

  if [[ -f "${hook_path}" ]] && ! rg -q "WS_CODEX_MANAGED_PRECOMMIT" "${hook_path}" 2>/dev/null; then
    if [[ ! -f "${backup_hook_path}" ]]; then
      mv "${hook_path}" "${backup_hook_path}"
      echo "Backed up existing pre-commit hook: ${backup_hook_path}"
    else
      echo "WARN: pre-commit.user already exists and current pre-commit is non-managed."
      echo "WARN: skipping managed-hook install for safety (no overwrite): ${repo}"
      continue
    fi
  fi

  cat > "${hook_path}" <<'EOF'
#!/usr/bin/env bash
# WS_CODEX_MANAGED_PRECOMMIT
set -euo pipefail

USER_HOOK_PATH="$(git rev-parse --git-path hooks)/pre-commit.user"

run_user_hook() {
  if [[ -x "${USER_HOOK_PATH}" ]]; then
    echo "[pre-commit] running preserved user hook: ${USER_HOOK_PATH}"
    "${USER_HOOK_PATH}"
  fi
}

if [[ "${WS_SKIP_CODEX_AUDIT:-0}" == "1" ]]; then
  echo "[pre-commit] codex audit skipped (WS_SKIP_CODEX_AUDIT=1)"
  run_user_hook
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

run_user_hook

if [[ -z "$(git diff --cached --name-only)" ]]; then
  exit 0
fi

if [[ -f package.json ]] && rg -q '"codex:audit:batch"' package.json 2>/dev/null; then
  echo "[pre-commit] running npm run codex:audit:batch"
  npm run codex:audit:batch
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "[pre-commit] ERROR: codex CLI not found and no codex:audit:batch script is available."
  echo "[pre-commit] Set WS_SKIP_CODEX_AUDIT=1 for an explicit temporary bypass."
  exit 1
fi

audit_tmp="$(mktemp)"
trap 'rm -f "$audit_tmp"' EXIT

{
  echo "Audit this staged diff for security/workflow/docs drift."
  echo "Return exactly:"
  echo "AUDIT_STATUS: PASS|FAIL"
  echo "SEVERITY_COUNTS: critical=<n> high=<n> medium=<n> low=<n>"
  echo "FINDINGS:"
  echo "- [severity][scope] issue | remediation"
  echo "- none"
  echo
  echo "If any critical/high findings exist, set AUDIT_STATUS: FAIL."
  echo
  echo "STAGED FILES:"
  git diff --cached --name-only
  echo
  echo "DIFF START"
  git diff --cached --no-color
  echo "DIFF END"
} | codex exec - -o "$audit_tmp"

if grep -q '^AUDIT_STATUS: FAIL' "$audit_tmp"; then
  echo "[pre-commit] codex audit failed:"
  cat "$audit_tmp"
  exit 1
fi

echo "[pre-commit] codex audit passed"
EOF
  chmod +x "${hook_path}"
  echo "Installed pre-commit codex audit hook: ${hook_path}"
done

echo "Done. Use WS_SKIP_CODEX_AUDIT=1 to bypass temporarily."
