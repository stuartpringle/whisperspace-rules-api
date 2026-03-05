# AGENTS

Canonical policy file for all Whisperspace repos.

Read this repo's `README.md` for project status, roadmap snapshot, and integration contract details. Keep `README.md` current for other repos (APIs/endpoints/schemas, auth expectations, build/publish/run steps, integration gotchas).

Read `/hdd/sites/stuartpringle/whisperspace-rules-api/AGENTS.md`, `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md`, and `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-SECURITY.md` for ecosystem context and security guardrails.

If present, read local context files before substantial edits:
- `.codex/PROJECT-HISTORY.md` (local verbose milestone/task history)
- `.codex/AUDIT-LOG.md` (local audit notes and prior findings)

Documentation discipline:
- Keep `README.md` concise and integration-focused.
- Keep verbose implementation history out of `README.md`; use `.codex/PROJECT-HISTORY.md` (gitignored) for local deep history.
- Update `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md` with this repo's latest status/milestones whenever contracts, release workflow, auth model, or shared integration behavior changes.

Workflow guardrails for each change batch:
1. At startup, review recent audit artifacts in `.codex/audits/` and `.codex/AUDIT-LOG.md`, then run `npm run codex:audit:status`. Report unresolved high/critical findings (or explicitly state none).
2. Pre-commit runs fast checks only:
   - Always-on lightweight checks: `git diff --cached --check` + `codex:audit:status`.
3. Post-commit queues asynchronous Codex review automatically through managed hooks:
   - Queue file: `.codex/audits/post-commit-queue.tsv`
   - Worker log: `.codex/audits/post-commit-worker.log`
   - Manual run for a commit: `npm run codex:audit:post-commit -- <commit>`
4. Run auto-resolution sweep for closed findings (`npm run codex:audit:autoresolve` or shared script path) when needed.
5. Resolve critical/high findings before merge.
6. Commit after each completed batch.
7. After each commit, re-check latest audit artifacts with `npm run codex:audit:status` and report any unresolved findings (especially repeated or previously unfixed issues).
8. Keep ecosystem guardrails synchronized (`npm run codex:ecosystem:sync`) when policy/helpers change.
9. Treat Claude scheduled audit cron as set-once + verify:
   - Install/update only when missing or drifted: `npm run claude:audit:cron:install -- 7`
   - Routine check: `npm run claude:audit:cron:check`
   - Report recent scheduled findings when relevant.

Shared helper location (single source of truth):
- `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/`

Engineering rule:
- Avoid duplicated logic. If behavior is needed in multiple flows, extract/reuse a shared helper/module instead of copying logic.

You have permission to edit outside this repo when updating `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md`.
