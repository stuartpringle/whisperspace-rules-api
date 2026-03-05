# Codex Shared Helpers

Canonical location for Whisperspace Codex automation helpers.

Scripts:
- `codex-batch-audit.sh`: per-batch staged/working-tree audit runner.
- `audit-autoresolve.sh`: auto-resolve logger for closed high/critical findings (`RESOLVED:` entries).
- `audit-status.sh`: unresolved high/critical status aggregator over `.codex/audits/*` + `.codex/AUDIT-LOG.md`.
- `codex-scheduled-audit.sh`: scheduled drift/security/docs audit runner.
- `claude-scheduled-audit.sh`: scheduled ecosystem audit using Claude CLI with file-path context.
- `install-claude-audit-cron.sh`: installs/updates the user crontab entry for daily Claude scheduled audits.
- `check-claude-audit-cron.sh`: verifies the managed Claude cron block exists and points to the scheduled audit command.
- `pre-commit-managed.sh`: managed pre-commit hook runtime used by all repos.
- `post-commit-managed.sh`: managed post-commit hook runtime that queues async Codex commit reviews.
- `post-commit-worker.sh`: single-worker queue processor for post-commit Codex reviews.
- `post-commit-review.sh`: commit-scoped Codex review runner (security/workflow/docs/contracts).
- `risk-trigger.sh`: detects risk-sensitive path changes to decide when full subprocess audits are required.
- `sync-agents-stubs.sh`: sync AGENTS stubs across all Whisperspace repos.
- `sync-ci-workflow.sh`: sync CI workflow (`codex-audit-status.yml`) across all repos.
- `verify-hooks.sh`: verify managed pre-commit hook wiring across all repos.

Used by:
- `scripts/codex-batch-audit.sh` (wrapper)
- `scripts/codex-audit-autoresolve.sh` (wrapper)
- `scripts/codex-audit-status.sh` (wrapper)
- `scripts/codex-scheduled-audit.sh` (wrapper)
- `scripts/codex-post-commit-review.sh` (wrapper)
- `scripts/codex-post-commit-worker.sh` (wrapper)
- `scripts/claude-scheduled-audit.sh` (wrapper)
- `scripts/install-claude-audit-cron.sh` (wrapper)
- `scripts/check-claude-audit-cron.sh` (wrapper)
- `scripts/install-codex-hooks-ecosystem.sh` (installer writes hook wrappers to call `pre-commit-managed.sh` + `post-commit-managed.sh`)
- `scripts/sync-codex-ecosystem.sh` (ecosystem sync wrapper)

Claude scheduled audit runtime env vars:
- `WS_CLAUDE_AUDIT_TIMEOUT_SEC` (seconds, optional; unset means no timeout)
- `WS_CLAUDE_AUDIT_REPOS` (optional comma-separated repo list override)
- `WS_CLAUDE_AUDIT_CRON_SCHEDULE` (optional cron schedule override for installer; default `17 3 * * *`)
- `WS_CLAUDE_AUDIT_DAYS` (optional default day window for cron installer when argument is omitted)
- `WS_POST_COMMIT_AUDIT_TIMEOUT_SEC` (seconds, optional; defaults to `900` for async post-commit Codex review)

Managed hook behavior:
- Pre-commit now runs fast checks only (`git diff --cached --check` + `audit-status`).
- Codex subprocess review runs asynchronously after commit through the managed post-commit queue.
- Emergency skip for post-commit queueing: `WS_SKIP_POST_COMMIT_CODEX_AUDIT=1`.

Emergency bypass telemetry:
- `pre-commit-managed.sh` appends bypass events to `.codex/BYPASS-LOG.tsv`.
- `audit-status.sh` reports bypass events since the previous commit via `BYPASS_EVENTS_*` output fields.

All Whisperspace repo `AGENTS.md` files should point to this location via the canonical policy file:
- `/hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md`
