# Local Codex Operational Files

This directory holds local context and audit artifacts that should not clutter committed project docs.

Local-only files (gitignored):
- `.codex/PROJECT-HISTORY.md`: verbose milestones, completed-task history, implementation notes.
- `.codex/AUDIT-LOG.md`: short operational notes and pointers to audit reports.
- `.codex/audits/*`: raw `codex exec` audit outputs and generated prompts.

Committed docs should stay concise:
- `README.md`: integration contract and usage notes for other repos.
- `PROJECT-OVERVIEW.md`: current dashboard/backlog snapshot.
- `PROJECT-SECURITY.md`: security baseline and active hardening guidance.
