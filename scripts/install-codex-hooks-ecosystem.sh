#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"

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

  if [[ -f "${hook_path}" ]] && ! grep -q "WS_CODEX_MANAGED_PRECOMMIT" "${hook_path}" 2>/dev/null; then
    if [[ ! -f "${backup_hook_path}" ]]; then
      mv "${hook_path}" "${backup_hook_path}"
      echo "Backed up existing pre-commit hook: ${backup_hook_path}"
    else
      echo "WARN: pre-commit.user already exists and current pre-commit is non-managed."
      echo "WARN: skipping managed-hook install for safety (no overwrite): ${repo}"
      continue
    fi
  fi

  cat > "${hook_path}" <<EOF
#!/usr/bin/env bash
# WS_CODEX_MANAGED_PRECOMMIT
set -euo pipefail
exec bash "${ROOT_SHARED}/pre-commit-managed.sh"
EOF

  chmod +x "${hook_path}"
  echo "Installed pre-commit codex audit hook: ${hook_path}"
done

echo "Done. Use WS_SKIP_CODEX_AUDIT=1 to bypass temporarily."
