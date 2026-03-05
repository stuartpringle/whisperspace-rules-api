# Codex Shared Helpers

Canonical location for Whisperspace Codex automation helpers.

Scripts:
- `codex-batch-audit.sh`: per-batch staged/working-tree audit runner.
- `codex-scheduled-audit.sh`: scheduled drift/security/docs audit runner.
- `pre-commit-managed.sh`: managed pre-commit hook runtime used by all repos.

Used by:
- `scripts/codex-batch-audit.sh` (wrapper)
- `scripts/codex-scheduled-audit.sh` (wrapper)
- `scripts/install-codex-hooks-ecosystem.sh` (installer writes hook wrappers to call `pre-commit-managed.sh`)

All Whisperspace repo `AGENTS.md` files should point to this location via the canonical policy file:
- `/hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md`
