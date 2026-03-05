# Codex Shared Helpers

Canonical location for Whisperspace Codex automation helpers.

Scripts:
- `codex-batch-audit.sh`: per-batch staged/working-tree audit runner.
- `codex-scheduled-audit.sh`: scheduled drift/security/docs audit runner.
- `claude-scheduled-audit.sh`: scheduled ecosystem audit using Claude CLI with file-path context.
- `pre-commit-managed.sh`: managed pre-commit hook runtime used by all repos.

Used by:
- `scripts/codex-batch-audit.sh` (wrapper)
- `scripts/codex-scheduled-audit.sh` (wrapper)
- `scripts/install-codex-hooks-ecosystem.sh` (installer writes hook wrappers to call `pre-commit-managed.sh`)

Claude scheduled audit runtime env vars:
- `WS_CLAUDE_AUDIT_TIMEOUT_SEC` (seconds, optional; unset means no timeout)
- `WS_CLAUDE_AUDIT_REPOS` (optional comma-separated repo list override)

All Whisperspace repo `AGENTS.md` files should point to this location via the canonical policy file:
- `/hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md`
