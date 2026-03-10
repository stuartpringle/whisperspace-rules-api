# Whisperspace Project Overview

## Scope
Whisperspace is a multi-repo TTRPG ecosystem. The objective is one canonical rules/data pipeline consumed by builder, VTT extensions, docs, and site surfaces with minimal contract drift.

Whisperspace is migrating from `/hdd/sites/stuartpringle/<repo>` to an ecosystem workspace rooted at `/hdd/sites/whisperspace`. The target layout is one shared control plane (`AGENTS.md`, `PROJECT-OVERVIEW.md`, `PROJECT-SECURITY.md`, `codex-shared/`) plus repo directories such as `rules-api`, `sdk`, `character-builder`, and `obr/<project>`. The legacy exception is `whisperspace-obr-extension`, which stays outside the new tree until retirement.

Security planning note:
- Cross-project security policy and hardening guidance lives in `PROJECT-SECURITY.md`.
- Active security audit findings should be logged there first, then summarized briefly here under risks.

## Repositories And Roles
- `whisperspace`
  - Public website + shared top-level nav JSON.
  - URL: `https://whisperspace.com`
  - Target path: `/hdd/sites/whisperspace/site`
- `whisperspace-rules-api`
  - Rules API, calc API, and character API.
  - URL: `https://rules-api.whisperspace.com`
  - Target path: `/hdd/sites/whisperspace/rules-api`
- `whisperspace-obr-extension`
  - Legacy player-facing Owlbear extension.
  - URL: `https://obr.whisperspace.com`
  - Legacy path retained: `/hdd/sites/stuartpringle/whisperspace-obr-extension`
- `whisperspace-obr-gm`
  - GM Owlbear extension.
  - URL: `https://gm.whisperspace.com`
  - Target path: `/hdd/sites/whisperspace/obr/gm`
- `whisperspace-character-builder`
  - Main character builder app.
  - URL: `https://builder.whisperspace.com`
  - Target path: `/hdd/sites/whisperspace/character-builder`
- `whisperspace-docs`
  - Public rules reference app.
  - URL: `https://docs.whisperspace.com`
  - Target path: `/hdd/sites/whisperspace/docs`
- `whisperspace-developer`
  - Developer docs site.
  - URL: `https://developer.whisperspace.com`
  - Target path: `/hdd/sites/whisperspace/developer`
- `whisperspace-rules-parser`
  - Internal parser from source doc to normalized YAML.
  - Target path: `/hdd/sites/whisperspace/rules-parser`
- `whisperspace-sdk`
  - Shared schema/types/utilities boundary.
  - Target path: `/hdd/sites/whisperspace/sdk`

## Integration Topology
1. Authoring: master rules document -> `whisperspace-rules-parser`.
2. Publication: parser output -> `whisperspace-rules-api` (`rules:publish` / `ecosystem:release`).
3. Consumption: builder + OBR extensions + docs read rules/calc/character endpoints.
4. Contract boundary: shared record/schema lives in `whisperspace-sdk`.

## Rules Data Workflow (This Repo)
1. Run parser and validate/diff.
2. Sync parser output into this repo.
3. Publish runtime artifacts (`rules-api`, `calc`, `character-api`) and run gates.

Quick commands:
```bash
npm run rules:publish
npm run ecosystem:release
```

## Versioning And Compatibility Matrix
Source of truth is `compatibility/matrix.json` + `compatibility/manifests/*.json` in this repo.

| Date | Active Release ID | Rules API | SDK | Builder | OBR | OBR GM | Docs | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-03-05 | `2026-03-05-baseline` | `0.1.0` | `1.1.0` | `1.0.0` | `1.0.0` | `1.0.0` | `1.0.0` | First enforced compatibility baseline |

## Shared Contracts Index
- Rules bundle: `https://rules-api.whisperspace.com/rules-api/latest/`
- Rules metadata: `https://rules-api.whisperspace.com/rules-api/latest/meta.json`
- Calc schemas: `https://rules-api.whisperspace.com/rules-api/calc/schemas/index.json`
- Character schema endpoint: `https://rules-api.whisperspace.com/character-api/schema.json`
- SDK schema source: `/hdd/sites/stuartpringle/whisperspace-sdk/schema/character-record.v1.json`

## Ecosystem Streamlining Backlog (2026-03-06)
### Program Goals
- Manageability: one reliable release path and one compatibility view.
- Maintainability: SDK-first shared contracts and fewer local adapters.
- Efficiency: fewer regressions, faster detection and recovery.

### Delivery Sequence
1. Foundation hardening (P0): compatibility + contract checks + release orchestration.
2. Shared runtime consolidation (P1): SDK-first adoption + shared platform client.
3. Operational maturity (P2): observability/SLOs + docs normalization.

### Progress Snapshot
- `ECO-001` complete (rules-api scope): compatibility matrix/manifests/validator enforced in publish flow.
- `ECO-002` complete (rules-api scope): contract smoke checks wired into publish flow.
- `ECO-003` complete (rules-api scope): `ecosystem:release` orchestrator live with summary artifact.
- `ECO-004` in progress: SDK readiness scaffold added (`compatibility/sdk-readiness.json`, `npm run sdk:readiness`) with shim-free gate enforcement for repos marked `complete`.
- `ECO-005` in progress: platform-client readiness scaffold is wired into `ecosystem:release`, SDK module shipped at `@whisperspace/sdk/platform-client`, builder phase-3 consumer migration landed, OBR phase-2 migration landed for Builder sync plus canonical OBR flows (public character fetch + auth session/csrf + public upsert, plus guest auth and canonical OBR-instance read/write) through shared SDK-backed adapters, and readiness tracker now reflects builder `complete`, OBR `in_progress`, OBR-GM `pending`.
- ECO tracking note: `npm run eco:readiness:scan` now generates `compatibility/eco-readiness-report.json` for current marker/usage inventory across ECO-004/005 repos.
- `ECO-006` in progress: observability telemetry/report artifacts are live, and the ecosystem baseline now lives at the root workspace rather than in this repo.
- `ECO-007` complete: overview normalized to dashboard format and ownership rules documented.
- `ECO-008` in progress: codex subprocess audit scripts + ecosystem hook installer now resolve through shared path helpers and are being lifted from a `rules-api`-centric control plane to the root Whisperspace workspace (`/hdd/sites/whisperspace`) with `codex-shared/` as the shared automation home; managed pre-commit now performs fast staged checks only while managed post-commit queues asynchronous commit-scoped Codex reviews, scheduled Claude audits are installable via centralized crontab helper and verifiable via centralized cron-check helper, post-commit worker stale-lock recovery now validates worker identity via PID plus `/proc` start-time checks to avoid dead queue blockage from PID reuse, CI workflow now enforces strict merge-time blocking on unresolved high/critical post-commit findings, and agent policy requires startup/post-commit `codex:audit:status` review of recent artifacts, explicit `codex:audit:autoresolve` sweeps when closing stale findings, `codex:ecosystem:sync` whenever shared guardrails/helpers change, and per-subproject `.codex/PROJECT-HISTORY.md` + `.codex/NEXT-STEPS.md` maintenance for local context.

### Backlog (Epics)
| ID | Priority | Epic | Primary Owner | Supporting Repos | Status |
| --- | --- | --- | --- | --- | --- |
| ECO-001 | P0 | Cross-repo compatibility matrix enforcement | `whisperspace-rules-api` maintainer | `sdk`, `builder`, `obr`, `obr-gm`, `docs` | Complete (rules-api scope) |
| ECO-002 | P0 | Contract smoke tests + post-deploy verification | `whisperspace-rules-api` maintainer | `builder`, `obr`, `obr-gm`, `docs` | Complete (rules-api scope) |
| ECO-003 | P0 | Single release orchestrator workflow | `whisperspace-rules-api` maintainer | all repos | Complete (rules-api scope) |
| ECO-004 | P1 | SDK-first contract adoption (remove production shims) | `whisperspace-sdk` maintainer | `obr`, `builder`, `rules-api` | In progress |
| ECO-005 | P1 | Shared Whisperspace platform client package | `whisperspace-sdk` maintainer | `builder`, `obr`, `obr-gm` | In progress |
| ECO-006 | P2 | Ecosystem observability + SLO baseline | `whisperspace-rules-api` maintainer | `obr`, `obr-gm`, `builder` | In progress |
| ECO-007 | P2 | Documentation normalization and ownership | `whisperspace-rules-api` maintainer | all repos | Complete |
| ECO-008 | P2 | Codex subprocess audit guardrails and drift detection | `whisperspace-rules-api` maintainer | all repos | In progress |

### Exit Criteria
- Contract-breaking changes fail pre/post deploy gates.
- Standard releases require one command (`ecosystem:release`).
- Builder + OBR + GM converge on shared SDK/platform client paths.
- Operators can identify likely root cause within 10 minutes from artifacts/metrics.

## Project Dashboard
This section is intentionally concise. Detailed changelogs belong in each repo's own README/CHANGELOG.

### whisperspace
- Status: Production site stable.
- Role in ecosystem: public brand/site + shared navigation source.
- Key integration dependencies: shared nav JSON consumed by builder.
- Next milestone: keep env/config standardization and release runbook hygiene.

### whisperspace-rules-api
- Status: Primary API surface live; publish gates active (`compat`, auth regression, contract smoke).
- Role in ecosystem: canonical runtime boundary for rules/calc/character data.
- Key integration dependencies: parser input; SDK schema contract; OBR/builder/docs clients.
- Next milestone: finish ECO-001/002/003 as fully complete and start ECO-004 integration constraints.

### whisperspace-obr-extension
- Status: Live and heavily active; broad gameplay/ownership/nanomancy workflows deployed.
- Role in ecosystem: player-side VTT runtime consuming rules/calc/character APIs.
- Key integration dependencies: rules-api contracts + SDK types.
- Current risk: residual local compatibility adapters/shims until ECO-004 is done.
- Latest milestone: ECO-005 phase-1 Builder sync migration landed; sheet public import/export and session/CSRF calls now route through a shared platform-client adapter.
- Next milestone: remove production shim paths and align fully to SDK release versions.

### whisperspace-obr-gm
- Status: Live GM extension with party/effects/adjudication/ownership modules.
- Role in ecosystem: GM control plane using shared OBR metadata/contracts.
- Key integration dependencies: OBR sheet metadata model + rules-api/character-api.
- Next milestone: continue feature expansion while preserving shared-contract discipline.

### whisperspace-character-builder
- Status: Live and feature-rich; active parity work with OBR and rules contracts.
- Role in ecosystem: canonical character authoring UX and share-link origin.
- Key integration dependencies: rules-api rules/calc + character-api + SDK schema.
- Latest milestone: phase-3 ECO-005 migration landed; auth session, auth POST flows (signup/login/logout/password request/reset), character-list/detail, save, and delete paths now route through a platform adapter that prefers SDK `createPlatformClient` (with compatibility fallback). Codex MCP integration note added: `database-explorer` must pass a MySQL URL argument to `@berthojoris/mcp-mysql-server` or startup initialize handshake fails.
- Next milestone: finalize SDK-first contract usage and reduce app-local integration logic.

### whisperspace-docs
- Status: Live rules reader with version-aware caching and search.
- Role in ecosystem: public rules consumption surface.
- Key integration dependencies: rules-api `rules.json` + `meta.json`.
- Next milestone: add release smoke checks and keep cache/version contract tight.

### whisperspace-developer
- Status: Needs explicit refresh.
- Role in ecosystem: source of integration runbooks and API usage guides.
- Next milestone: publish current API/auth/contracts/deploy docs synced to gates introduced in ECO-001/002/003.

### whisperspace-rules-parser
- Status: Active upstream parser for canonical rules extraction.
- Role in ecosystem: single source-to-YAML transformation point.
- Next milestone: document parser release cadence + quality gates in parser repo docs.

### whisperspace-sdk
- Status: Shared schema/types live; adopted by multiple repos.
- Role in ecosystem: contract boundary package.
- Current risk: downstream shim usage still exists in some clients.
- Latest milestone: shared platform-client module now covers rules/calc/character/auth plus OBR guest auth and canonical OBR-instance read/write wrappers, exported via `@whisperspace/sdk/platform-client`.
- Next milestone: complete OBR and OBR GM migrations from local shims/adapters to direct SDK platform-client consumption and remove remaining repo-local compatibility wrappers.

## Cross-Repo Risks (Current)
- SDK adoption is not fully enforced in all runtime paths (`ECO-004` pending).
- Some repos still carry legacy/local compatibility code that can drift from released contracts.
- Security audit is running in parallel; unresolved high/critical findings from `PROJECT-SECURITY.md` should block promotion.

## Documentation Ownership Rules
- This file (`PROJECT-OVERVIEW.md`): architecture map, roadmap/backlog, compatibility snapshot, concise per-repo status.
- Per-repo README/CHANGELOG: detailed milestones, implementation history, local operational notes.
- Security policies/findings: `PROJECT-SECURITY.md`.
- MCP prerequisites: each active repo README includes a `Codex MCP Prerequisites` section and `scripts/check-mcp.sh`; keep those in sync when MCP requirements change.
- Local verbose context (gitignored): `.codex/PROJECT-HISTORY.md`, `.codex/AUDIT-LOG.md`, `.codex/audits/*`.

## Review Cadence
- Update this overview at least once per release batch that changes contracts or deployment workflow.
- Monthly: review ECO backlog status and observability/SLO effectiveness.
