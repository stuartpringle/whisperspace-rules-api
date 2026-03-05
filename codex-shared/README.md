# Codex Shared Helpers

Canonical location for Whisperspace Codex automation helpers.

Scripts:
- `codex-batch-audit.sh`: per-batch staged/working-tree audit runner.
- `audit-autoresolve.sh`: auto-resolve logger for closed high/critical findings (`RESOLVED:` entries).
- `audit-status.sh`: unresolved high/critical status aggregator over `.codex/audits/*` + `.codex/AUDIT-LOG.md`.
- `codex-scheduled-audit.sh`: scheduled drift/security/docs audit runner.
- `claude-scheduled-audit.sh`: scheduled ecosystem audit using Claude CLI with file-path context.
- `pre-commit-managed.sh`: managed pre-commit hook runtime used by all repos.
- `sync-agents-stubs.sh`: sync AGENTS stubs across all Whisperspace repos.
- `sync-ci-workflow.sh`: sync CI workflow (`codex-audit-status.yml`) across all repos.
- `verify-hooks.sh`: verify managed pre-commit hook wiring across all repos.

Used by:
- `scripts/codex-batch-audit.sh` (wrapper)
- `scripts/codex-audit-autoresolve.sh` (wrapper)
- `scripts/codex-audit-status.sh` (wrapper)
- `scripts/codex-scheduled-audit.sh` (wrapper)
- `scripts/install-codex-hooks-ecosystem.sh` (installer writes hook wrappers to call `pre-commit-managed.sh`)
- `scripts/sync-codex-ecosystem.sh` (ecosystem sync wrapper)

Claude scheduled audit runtime env vars:
- `WS_CLAUDE_AUDIT_TIMEOUT_SEC` (seconds, optional; unset means no timeout)
- `WS_CLAUDE_AUDIT_REPOS` (optional comma-separated repo list override)

All Whisperspace repo `AGENTS.md` files should point to this location via the canonical policy file:
- `/hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md`
