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
2. Pre-commit runs in fast-path mode by default:
   - Always-on lightweight checks: `git diff --cached --check` + `codex:audit:status`.
   - Trigger source: `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/risk-trigger.sh`.
   - Full codex subprocess audits (`codex:audit:batch` + `codex:audit:docs`) run for code/config/workflow/security/API/schema paths and fail closed for any non-allowlisted path.
   - Full audits are skipped only when all changed files are in the low-risk allowlist (docs/static assets).
3. Force full codex audit for any commit with `WS_FORCE_FULL_CODEX_AUDIT=1`.
4. Emergency bypass is explicit only:
   - `WS_SKIP_CODEX_AUDIT=1` requires `WS_MANUAL_AUDIT_ACK=I_RAN_CODEX_AUDITS` and `WS_BYPASS_REASON="<ticket or short reason>"` after manual batch/docs audits.
   - Risk-triggered changes still require full subprocess audits unless `WS_ALLOW_RISKY_SKIP=1` is also set.
   - Every emergency bypass is written to `.codex/BYPASS-LOG.tsv` and surfaced by `codex:audit:status`.
5. Run auto-resolution sweep for closed findings (`npm run codex:audit:autoresolve` or shared script path) when needed.
6. Resolve critical/high findings before commit.
7. Commit after each completed batch.
8. After each commit, re-check latest audit artifacts with `npm run codex:audit:status` and report any unresolved findings (especially repeated or previously unfixed issues).
9. Keep ecosystem guardrails synchronized (`npm run codex:ecosystem:sync`) when policy/helpers change.

Shared helper location (single source of truth):
- `/hdd/sites/stuartpringle/whisperspace-rules-api/codex-shared/`

Engineering rule:
- Avoid duplicated logic. If behavior is needed in multiple flows, extract/reuse a shared helper/module instead of copying logic.

You have permission to edit outside this repo when updating `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md`.
