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
2. Run a codex guardrail audit before commit.
   - Preferred: `npm run codex:audit:batch` (shared implementation at `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/codex-batch-audit.sh`).
   - Fallback: `git diff --staged | codex exec "Audit this diff for security/workflow/docs drift. Return critical/high findings first."`
3. Run documentation audit before commit (`npm run codex:audit:docs` or shared script path).
4. Run auto-resolution sweep for closed findings (`npm run codex:audit:autoresolve` or shared script path).
5. Resolve critical/high findings before commit.
6. Commit after each completed batch.
7. After each commit, re-check latest audit artifacts with `npm run codex:audit:status` and report any unresolved findings (especially repeated or previously unfixed issues).
8. Keep ecosystem guardrails synchronized (`npm run codex:ecosystem:sync`) when policy/helpers change.

Shared helper location (single source of truth):
- `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/`

Engineering rule:
- Avoid duplicated logic. If behavior is needed in multiple flows, extract/reuse a shared helper/module instead of copying logic.

You have permission to edit outside this repo when updating `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md`.
