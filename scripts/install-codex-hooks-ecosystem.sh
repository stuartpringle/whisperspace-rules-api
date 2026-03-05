#!/usr/bin/env bash
set -euo pipefail

ROOT_SHARED="/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared"
source "${ROOT_SHARED}/ecosystem-repos.sh"

for repo in "${WS_REPOS[@]}"; do
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

  pre_hook_path="${hooks_dir}/pre-commit"
  pre_backup_hook_path="${hooks_dir}/pre-commit.user"
  post_hook_path="${hooks_dir}/post-commit"
  post_backup_hook_path="${hooks_dir}/post-commit.user"
  mkdir -p "${hooks_dir}"

  if [[ -f "${pre_hook_path}" ]] && ! grep -q "WS_CODEX_MANAGED_PRECOMMIT" "${pre_hook_path}" 2>/dev/null; then
    if [[ ! -f "${pre_backup_hook_path}" ]]; then
      mv "${pre_hook_path}" "${pre_backup_hook_path}"
      echo "Backed up existing pre-commit hook: ${pre_backup_hook_path}"
    else
      echo "WARN: pre-commit.user already exists and current pre-commit is non-managed."
      echo "WARN: skipping managed-hook install for safety (no overwrite): ${repo}"
      continue
    fi
  fi

  if [[ -f "${post_hook_path}" ]] && ! grep -q "WS_CODEX_MANAGED_POSTCOMMIT" "${post_hook_path}" 2>/dev/null; then
    if [[ ! -f "${post_backup_hook_path}" ]]; then
      mv "${post_hook_path}" "${post_backup_hook_path}"
      echo "Backed up existing post-commit hook: ${post_backup_hook_path}"
    else
      echo "WARN: post-commit.user already exists and current post-commit is non-managed."
      echo "WARN: skipping managed-hook install for safety (no overwrite): ${repo}"
      continue
    fi
  fi

  cat > "${pre_hook_path}" <<EOF
#!/usr/bin/env bash
# WS_CODEX_MANAGED_PRECOMMIT
set -euo pipefail
exec bash "${ROOT_SHARED}/pre-commit-managed.sh"
EOF

  cat > "${post_hook_path}" <<EOF
#!/usr/bin/env bash
# WS_CODEX_MANAGED_POSTCOMMIT
set -euo pipefail
exec bash "${ROOT_SHARED}/post-commit-managed.sh"
EOF

  chmod +x "${pre_hook_path}" "${post_hook_path}"
  echo "Installed pre-commit codex audit hook: ${pre_hook_path}"
  echo "Installed post-commit codex audit hook: ${post_hook_path}"
done

echo "Done. Pre-commit now runs fast checks only; Codex subprocess review runs asynchronously after commit via managed post-commit queue."
