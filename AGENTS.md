# AGENTS

Canonical policy file for all Whisperspace repos.

Primary workspace model:
- Prefer opening Codex from the Whisperspace ecosystem root: `/hdd/sites/whisperspace` when present.
- Treat individual repos as subprojects within one shared workspace, not as isolated control planes.

Read this repo's `README.md` for project status, roadmap snapshot, and integration contract details. Keep `README.md` current for other repos (APIs/endpoints/schemas, auth expectations, build/publish/run steps, integration gotchas).

Read the canonical ecosystem context files first:
- `AGENTS.md`
- `PROJECT-OVERVIEW.md`
- `PROJECT-SECURITY.md`

Path resolution note:
- Shared scripts should resolve through `WS_ECOSYSTEM_ROOT` / `WS_SHARED_ROOT` rather than hardcoded `/hdd/sites/stuartpringle/...` paths.
- Target ecosystem layout is `/hdd/sites/whisperspace/<project>` with OBR repos under `/hdd/sites/whisperspace/obr/<project>`.
- Legacy exception: `whisperspace-obr-extension` remains outside the new tree until retired.

If present, read local context files before substantial edits:
- `.codex/PROJECT-HISTORY.md` (local verbose milestone/task history)
- `.codex/NEXT-STEPS.md` (current local TODO/next actions)
- `.codex/AUDIT-LOG.md` (local audit notes and prior findings)

Documentation discipline:
- Keep `README.md` concise and integration-focused.
- Keep verbose implementation history out of `README.md`; use `.codex/PROJECT-HISTORY.md` (gitignored) for local deep history.
- Keep `.codex/NEXT-STEPS.md` current with the next concrete actions for this subproject.
- Update `PROJECT-OVERVIEW.md` with this repo's latest status/milestones whenever contracts, release workflow, auth model, or shared integration behavior changes.

Workflow guardrails for each change batch:
1. At startup, review recent audit artifacts in `.codex/audits/` and `.codex/AUDIT-LOG.md`, then run `npm run codex:audit:status`. Report unresolved high/critical findings (or explicitly state none).
2. Pre-commit runs fast checks only:
   - Always-on lightweight checks: `git diff --cached --check` + `codex:audit:status`.
3. Post-commit queues asynchronous Codex review automatically through managed hooks:
   - Queue file: `.codex/audits/post-commit-queue.tsv`
   - Worker log: `.codex/audits/post-commit-worker.log`
   - Manual run for a commit: `npm run codex:audit:post-commit -- <commit>`
4. Merge-time blocking gate is required:
   - CI must run strict post-commit audit gate (`npm run codex:audit:ci:post-commit-gate` or shared script path).
   - High/critical unresolved findings in post-commit reports must block merge.
5. Run auto-resolution sweep for closed findings (`npm run codex:audit:autoresolve` or shared script path) when needed.
6. Resolve critical/high findings before merge.
7. Commit after each completed batch.
8. After each commit, re-check latest audit artifacts with `npm run codex:audit:status` and report any unresolved findings (especially repeated or previously unfixed issues).
9. Keep ecosystem guardrails synchronized (`npm run codex:ecosystem:sync`) when policy/helpers change.
10. Treat Claude scheduled audit cron as set-once + verify:
   - Install/update only when missing or drifted: `npm run claude:audit:cron:install -- 7`
   - Routine check: `npm run claude:audit:cron:check`
   - Report recent scheduled findings when relevant.

Shared helper location (single source of truth):
- `WS_SHARED_ROOT` when set
- target canonical path: `/hdd/sites/whisperspace/codex-shared/`
- transitional bootstrap path while migration is in progress: this repo's `codex-shared/`

Engineering rule:
- Avoid duplicated logic. If behavior is needed in multiple flows, extract/reuse a shared helper/module instead of copying logic.

You have permission to edit outside this repo when updating the canonical `PROJECT-OVERVIEW.md` / `PROJECT-SECURITY.md` / root workspace notes during the ecosystem-root migration.
