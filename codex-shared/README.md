# Codex Shared Helpers

Canonical location for Whisperspace Codex automation helpers.

Scripts:
- `codex-batch-audit.sh`: per-batch staged/working-tree audit runner.
- `audit-autoresolve.sh`: auto-resolve logger for closed high/critical findings (`RESOLVED:` entries).
- `audit-status.sh`: unresolved high/critical status aggregator over `.codex/audits/*` + `.codex/AUDIT-LOG.md`.
- `codex-scheduled-audit.sh`: scheduled drift/security/docs audit runner.
- `claude-scheduled-audit.sh`: scheduled ecosystem audit using Claude CLI with file-path context.
- `install-claude-audit-cron.sh`: installs/updates the user crontab entry for daily Claude scheduled audits.
- `pre-commit-managed.sh`: managed pre-commit hook runtime used by all repos.
- `risk-trigger.sh`: detects risk-sensitive path changes to decide when full subprocess audits are required.
- `sync-agents-stubs.sh`: sync AGENTS stubs across all Whisperspace repos.
- `sync-ci-workflow.sh`: sync CI workflow (`codex-audit-status.yml`) across all repos.
- `verify-hooks.sh`: verify managed pre-commit hook wiring across all repos.

Used by:
- `scripts/codex-batch-audit.sh` (wrapper)
- `scripts/codex-audit-autoresolve.sh` (wrapper)
- `scripts/codex-audit-status.sh` (wrapper)
- `scripts/codex-scheduled-audit.sh` (wrapper)
- `scripts/claude-scheduled-audit.sh` (wrapper)
- `scripts/install-claude-audit-cron.sh` (wrapper)
- `scripts/install-codex-hooks-ecosystem.sh` (installer writes hook wrappers to call `pre-commit-managed.sh`)
- `scripts/sync-codex-ecosystem.sh` (ecosystem sync wrapper)

Claude scheduled audit runtime env vars:
- `WS_CLAUDE_AUDIT_TIMEOUT_SEC` (seconds, optional; unset means no timeout)
- `WS_CLAUDE_AUDIT_REPOS` (optional comma-separated repo list override)
- `WS_CLAUDE_AUDIT_CRON_SCHEDULE` (optional cron schedule override for installer; default `17 3 * * *`)
- `WS_CLAUDE_AUDIT_DAYS` (optional default day window for cron installer when argument is omitted)

Managed pre-commit fast-path env vars:
- `WS_SKIP_CODEX_AUDIT=1` bypasses Codex subprocess audits in pre-commit (fast checks/status still run).
- `WS_SKIP_CODEX_AUDIT=1` is emergency-only and requires `WS_MANUAL_AUDIT_ACK=I_RAN_CODEX_AUDITS` plus `WS_BYPASS_REASON="<ticket or short reason>"` (after manual `codex:audit:batch` + `codex:audit:docs`).
- Risk-triggered change sets still run full subprocess audits unless `WS_ALLOW_RISKY_SKIP=1` is also set for explicit emergency bypass.
- `WS_FORCE_FULL_CODEX_AUDIT=1` forces full subprocess audits on every commit.
- `WS_CODEX_RISK_REGEX` overrides default risk-path regex used by `risk-trigger.sh`.
- `WS_CODEX_LOW_RISK_ONLY_REGEX` overrides the low-risk allowlist regex used by `risk-trigger.sh`.

Emergency bypass telemetry:
- `pre-commit-managed.sh` appends bypass events to `.codex/BYPASS-LOG.tsv`.
- `audit-status.sh` reports bypass events since the previous commit via `BYPASS_EVENTS_*` output fields.

All Whisperspace repo `AGENTS.md` files should point to this location via the canonical policy file:
- `/hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md`
