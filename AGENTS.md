# AGENTS

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
1. Run a codex guardrail audit before commit.
   - Preferred: `npm run codex:audit:batch` (if this repo provides it).
   - Fallback: `git diff --staged | codex exec "Audit this diff for security/workflow/docs drift. Return critical/high findings first."`
2. Resolve critical/high findings before commit.
3. Commit after each completed batch.

Engineering rule:
- Avoid duplicated logic. If behavior is needed in multiple flows, extract/reuse a shared helper/module instead of copying logic.

You have permission to edit outside this repo when updating `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md`.
