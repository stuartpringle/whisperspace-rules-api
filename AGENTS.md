# AGENTS

Read `PROJECT-OVERVIEW.md` and `README.md` for project context, then update `README.md` with the current state of the project (roadmap, goals, completed items, and progress on unfinished work). Keep `README.md` up to date with how other projects should interact with this project (APIs, endpoints, schemas, build/publish steps, auth expectations, and any integration gotchas). Other repos are expected to consult this `README.md`.

Read `PROJECT-SECURITY.md` before implementing auth, CORS, CSRF, ownership, or release workflow changes.

If present, read local context files for verbose implementation history and prior audit notes:
- `.codex/PROJECT-HISTORY.md`
- `.codex/AUDIT-LOG.md`

Use docs split discipline:
- Keep `README.md` integration-focused and concise.
- Keep `PROJECT-OVERVIEW.md` as a concise dashboard and milestones snapshot.
- Record verbose milestones/completed-task history in `.codex/PROJECT-HISTORY.md` (local-only, gitignored).

Before each commit batch, run:
- `npm run codex:audit:batch`
- If codex CLI is unavailable, note the skip in your final summary.

Update `/hdd/sites/stuartpringle/whisperspace-rules-api/PROJECT-OVERVIEW.md` with this repo's current status and milestones. You have permission to edit outside this repo for that purpose.

After each batch of changes, commit the changes to git. You have permission to do so.
