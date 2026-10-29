# Whisperspace Rules API

This repo hosts the shared rules API, calc endpoints, and core module used by Whisperspace clients.

Quick publish:
```bash
npm run rules:publish
```
`rules:publish` now resolves through the root workspace publish flow when run inside the workspace, while `rules-api` keeps explicit repo-local internals such as `core:build`, `rules:sync`, and `publish:runtime`.
It also publishes Character API runtime files (`public/character-api/index.php`, `.htaccess`, `.env.example`) into `dist/character-api`, so new Character API routes are deployed alongside rules/calc updates.
It now also runs a compatibility gate (`npm run compat:check`) using `compatibility/matrix.json` + `compatibility/manifests/*.json` before publish continues.
After publish, it runs contract smoke verification (`npm run contract:smoke`) against critical rules/calc/character-api endpoints.
If needed for constrained environments where local port binding is unavailable, you can bypass this gate explicitly:
```bash
WS_SKIP_CHARACTER_AUTH_TEST=1 npm run rules:publish
```
To skip post-publish contract smoke checks explicitly:
```bash
WS_SKIP_CONTRACT_SMOKE=1 npm run rules:publish
```

Character API ownership regression:
```bash
npm run test:character-auth
npm run publish:runtime
```

Compatibility gate:
```bash
npm run compat:check
```
ECO readiness inventory scan:
```bash
npm run eco:readiness:scan
```

Contract smoke checks:
```bash
npm run contract:smoke
```

Ecosystem smoke checks:
```bash
npm run ecosystem:smoke
```

Single release orchestrator:
```bash
npm run ecosystem:release
```
On success this writes `dist/ecosystem-release-summary.json` with publish metadata and gate status.
It runs these gates in-order: `rules:publish`, `ecosystem:smoke`, `compat:check`, `sdk:readiness`, `platform:readiness`.
It also writes structured observability artifacts:
- `dist/ecosystem-observability.json` (step durations/status + failure signal)
- `dist/telemetry/ecosystem-release.ndjson` (run/step events for ingestion)

Batch guardrail audit (Codex CLI subprocess):
```bash
npm run codex:audit:batch
```
Manual post-commit audit for a specific commit:
```bash
npm run codex:audit:post-commit -- HEAD
```
CI merge gate (strict unresolved high/critical check on post-commit reports):
```bash
npm run codex:audit:ci:post-commit-gate
```
Codex multi-agent orchestrator (fan-out task list, default max 4):
```bash
npm run codex:orchestrate -- --tasks .codex/tasks.txt --max-agents 4
```
Repository-level scheduled audit:
```bash
npm run codex:audit:repo -- 7
```
Claude scheduled ecosystem audit (path-based context):
```bash
npm run claude:audit:repo -- 7
```
Install/update daily Claude scheduled audit via user crontab (setup or drift repair):
```bash
npm run claude:audit:cron:install -- 7
```
Verify scheduled Claude cron wiring:
```bash
npm run claude:audit:cron:check
```
Runtime controls:
- `WS_CLAUDE_AUDIT_TIMEOUT_SEC` (optional; unset means no timeout)
- `WS_CLAUDE_AUDIT_REPOS` (optional comma-separated override for targeted runs)
- `WS_CLAUDE_AUDIT_CRON_SCHEDULE` (optional cron expression override for installer; default `17 3 * * *`)
- `WS_CLAUDE_AUDIT_DAYS` (optional default day window for cron installer when CLI arg is omitted)
- `WS_POST_COMMIT_AUDIT_TIMEOUT_SEC` (optional; timeout for async Codex post-commit review, default `900`)
Documentation drift audit:
```bash
npm run codex:audit:docs
```
Install/update pre-commit audit hooks across Whisperspace repos:
```bash
npm run codex:hooks:install
```
Shared helper root (canonical target):
- `/hdd/sites/whisperspace/codex-shared/`
Migration note:
- While the ecosystem-root move is in progress, scripts should resolve shared helpers through `WS_SHARED_ROOT` / `WS_ECOSYSTEM_ROOT` and fall back to the current repo-local `codex-shared/`.

Observability baseline config:
- `/hdd/sites/whisperspace/observability/baseline.json` defines ecosystem-level SLO targets, alert thresholds, and standard log fields consumed by the root release observability flow.

Primary workspace:
- Prefer opening Codex from `/hdd/sites/whisperspace` once the move is complete; that root will be the ecosystem control plane.

Related repos:
- `whisperspace-obr-extension`
- `whisperspace-obr-rules-extension`
- `whisperspace-sdk`
- `whisperspace-character-builder`

## Rules Data Workflow

Rules data comes from the **Whisperspace Rules Parser**.
Parser README: `/hdd/sites/stuartpringle/whisperspace-rules-parser/README.md`

### Update Rules

1. Run the parser:
   ```bash
   PYTHONPATH=src python3 -m whisperspace_rules_parser.cli --out out --validate --diff
   ```
2. Sync rules into this repo:
   ```bash
   npm run rules:sync
   ```
3. Publish:
   ```bash
   npm run rules:publish
   ```

## HTTP Rules API

Published at:
- `https://rules-api.whisperspace.com/rules-api/latest/`

Key files:
- `rules.json` (full rules tree)
- `assets/images/*` (images referenced in rules content)
- `skills.json`, `weapons.json`, `armour.json`, `items.json`, `cyberware.json`, `narcotics.json`, `hacking_gear.json`
- `weapon_keywords.json`, `skill_tooltips.json`
- `meta.json` (semver + hashes)
- `chapters/index.json` + `chapters/<slug>.json` (each chapter of `rules.json` as its own minified file, sized for AI tools/agents that can't take the full 760KB tree in one fetch; written by `generate:data`, not listed in `meta.json`). Each index entry has a content `sha256` and an `updatedAt` that only changes when that chapter's content changes (seeded from git history on first appearance); the docs sitemap uses it for `<lastmod>`.

### Skill Tooltips

Endpoint:
- `GET https://rules-api.whisperspace.com/rules-api/latest/skill_tooltips.json`

Payload shape:
- `attributes` / `attributesById`: keyed by attribute ids (`phys`, `ref`, `soc`, `ment`)
- `attributesByShort`: keyed by short labels (`PHYS`, `REF`, `SOC`, `MENT`)
- `skills` / `skillsById`: keyed by skill ids from `skills.json` (example: `stealth`, `weapons_light`)
- `skillsByLabel`: keyed by display labels (backward compatibility)

Integration note:
- New consumers should use `skills` and `attributes` (ID-based maps).
- `skillsByLabel` and `attributesByShort` are kept for compatibility with older clients.

### Core Module (HTTP)

```js
import { buildAttackOutcome, deriveAttributesFromSkills } from "https://rules-api.whisperspace.com/rules-api/latest/core/index.js";
```

### Calc Endpoints (PHP)

All endpoints are `POST` and accept JSON bodies. No auth required.
Rate limit: 120 requests per minute per IP (best-effort).
Schemas: `https://rules-api.whisperspace.com/rules-api/calc/schemas/index.json`

Endpoints:
- `/rules-api/calc/attack`
- `/rules-api/calc/crit-extra`
- `/rules-api/calc/damage`
- `/rules-api/calc/derive-attributes`
- `/rules-api/calc/derive-cuf`
- `/rules-api/calc/skill-notation`
- `/rules-api/calc/skill-mod`
- `/rules-api/calc/status-deltas`
- `/rules-api/calc/status-apply`
- `/rules-api/calc/ammo-max`
- `/rules-api/calc/point-budget`
- `/rules-api/calc/validate-sheet`

Gameplay effects contract (new):
- Supported on calc endpoints that derive attributes/stats: `/derive-attributes`, `/derive-cuf`, `/derive-speed`, `/derive-capacity`, `/skill-mod` (and accepted by `/validate-sheet` for shared payload shape).
- Field name on equipment/feat templates: `gameplayEffects` (string).
- Format: comma-separated deltas, e.g. `carrying_capacity+5, stealth-1, phys+1`.
- Effects are additive across all provided non-empty sources:
  - top-level `gameplayEffects: string[]`
  - equipment payloads containing `gameplayEffects`/`gameplayEffect` under `weapons`, `armour`, `items`, `feats`, `inventory`, or `sheet`.
  - snake_case variants are also accepted: `gameplay_effects`, `gameplay_effect`.
- Programmatic extraction:
  - During gear parsing (`scripts/parse-gear.mjs`), if the source table has no gameplay-effects column, a best-effort parser infers effects from plain-English text (for example, `+5 Inventory Slots when worn` -> `carrying_capacity+5`).
  - During calc requests, if a feat/item/armour/weapon object has no explicit `gameplayEffects`, the calc API also performs best-effort extraction from `effect`/`special`/`description`/`text` fields.
- Recommendation:
  - Treat explicit `gameplayEffects` in parser output as the canonical contract for clients.
  - Keep inference enabled as a safety net for upstream wording drift, but prefer explicit fields whenever available.
- Clamping rules:
  - Skill deltas never reduce a skill rank below `0`.
  - Derived values (`speed`, `carryingCapacity`, `cuf`) are clamped at minimum `0`.
- Response note:
  - These endpoints now include a `gameplayDeltas` object showing what was applied to `attributes`, `derived`, and `skills`.
Integration gotchas:
- Do not send a top-level `gameplayEffects` array that is built from the same gear/feat entries you also include in the request body. The calc API merges effects from both the top-level list and the gear payloads, so you will double-apply effects.
- When mapping rules catalog entries into a character sheet payload, include the rules data `gameplayEffects` field on items/weapons/armour/feats (or ensure the `effect`/`description` text is passed through so inference can work).

Common gameplay effect keys:
- Attributes: `phys`, `ref`, `soc`, `ment`
- Derived: `cool_under_fire`, `speed`, `carrying_capacity`
- Skills/stats: use the skill id (example: `stealth`)
- Aliases accepted: `cuf` -> `cool_under_fire`, `carryingCapacity`/`inventorySlots` -> `carrying_capacity`

Examples:

`POST /rules-api/calc/derive-capacity`
```json
{
  "phys": 2,
  "items": [
    { "name": "Compact Backpack", "gameplayEffects": "carrying_capacity+5" }
  ]
}
```
Response:
```json
{
  "carryingCapacity": 20,
  "gameplayDeltas": {
    "attributes": { "phys": 0, "ref": 0, "soc": 0, "ment": 0 },
    "derived": { "coolUnderFire": 0, "speed": 0, "carryingCapacity": 5 },
    "skills": {}
  }
}
```

`POST /rules-api/calc/skill-mod`
```json
{
  "learnedByFocus": { "combat": [{ "id": "stealth" }] },
  "skillId": "stealth",
  "learningFocus": "combat",
  "ranks": { "stealth": 1 },
  "skillMods": {},
  "gameplayEffects": ["stealth-1"]
}
```
Response:
```json
{
  "modifier": 0,
  "skillDelta": -1,
  "effectiveRank": 0,
  "gameplayDeltas": {
    "attributes": { "phys": 0, "ref": 0, "soc": 0, "ment": 0 },
    "derived": { "coolUnderFire": 0, "speed": 0, "carryingCapacity": 0 },
    "skills": { "stealth": -1 }
  }
}
```

`POST /rules-api/calc/derive-attributes`
```json
{
  "skills": { "athletics": 2, "stealth": 1 },
  "inherentSkills": [
    { "id": "athletics", "attribute": "phys" },
    { "id": "stealth", "attribute": "ref" }
  ],
  "gameplayEffects": ["stealth-1", "phys+1"]
}
```
Response includes final attributes plus `gameplayDeltas` so clients can show exactly which stat/attribute adjustments were applied.

Example feat text inference:
- Input feat object:
  ```json
  {
    "name": "Military Discipline",
    "description": "Increase Cool Under Fire by +1. Additionally, once per turn you may ignore penalty dice from Suppressing Fire."
  }
  ```
- Inferred gameplay effect: `cool_under_fire+1` (penalty-dice language is ignored by gameplay rank/derived parser).

## Character API (MySQL-backed)

Base URL:
- `https://rules-api.whisperspace.com/character-api`

Environment:
- The character API loads env files in this order (later files can override earlier values):
  - `/hdd/sites/stuartpringle/whisperspace-rules-api/.env`
  - `/hdd/sites/stuartpringle/whisperspace-rules-api/public/character-api/.env`
  - `/hdd/sites/stuartpringle/whisperspace-rules-api/dist/character-api/.env`
- Keep one authoritative env file updated (prefer `/hdd/sites/stuartpringle/whisperspace-rules-api/.env`) with:
  - `WS_CHARACTER_API_KEY` and optional overrides for `WS_CHARACTER_DB_PATH`/`WS_CHARACTER_SCHEMA_PATH`.
  - MySQL settings: `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_SOCKET` (if using UNIX socket), `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`.
  - `WS_COOKIE_DOMAIN` (e.g. `.whisperspace.com`) and `WS_BUILDER_URL` used in password-reset emails.
  - Mail/Postmark secrets: `POSTMARK_SERVER_TOKEN`, `MAIL_FROM`, `MAIL_REPLY_TO`, `MAIL_APP_NAME`.
  - Google OAuth hooks when enabled: `WS_OAUTH_GOOGLE_CLIENT_ID`, `WS_OAUTH_GOOGLE_CLIENT_SECRET`, `WS_OAUTH_GOOGLE_REDIRECT_URI`.
  - Keep Postmark/mail values in this file rather than exposing a public `.env`.
- Database boundary rule: character-api must use `DB_DATABASE=stuartpringle_whisperspace_character_builder`; do not point character-api to `stuartpringle_whisperspace` (Statamic website DB).

Auth (shared key):
- Set `WS_CHARACTER_API_KEY` inside `/hdd/sites/stuartpringle/whisperspace-rules-api/.env`.
- Clients still authenticate with `Authorization: Bearer <key>` or `?api_key=...`.

Auth endpoints:
- `POST /character-api/auth/signup`
- `POST /character-api/auth/login`
- `POST /character-api/auth/logout`
- `GET /character-api/auth/session`
- `GET /character-api/auth/csrf`
- `POST /character-api/auth/obr-guest`
- `POST /character-api/auth/obr-room-capability`
- `POST /character-api/auth/password/request`
- `POST /character-api/auth/password/reset`
- `GET /character-api/auth/oauth/google`

Auth contract:
- **Request/response shapes:**
  - `POST /character-api/auth/signup` / `POST /character-api/auth/login`: body `{ "email": "...", "password": "..." }`. Successful responses return `201`/`200` with `{ "user": { "id": "<uuid>", "email": "<email>" } }`. Failures return `{ "error": "<code>" }` (e.g., `invalid_credentials`, `user_exists`, `validation_failed`).
  - `POST /character-api/auth/logout`: no body; responds `200` with `{ "ok": true }` and clears `ws_session`/`ws_csrf` cookies. Requires `X-CSRF-Token` header matching the `ws_csrf` cookie.
  - `GET /character-api/auth/session`: returns `200` with `{ "user": null, "csrfToken": "<token>" }` when no session or `{ "user": { "id": "<uuid>", "email": "<email>" }, "csrfToken": "<token>" }` when authenticated.
  - `GET /character-api/auth/csrf`: returns `200` with `{ "csrfToken": "<token>", "authenticated": <boolean> }` for clients that need an explicit CSRF read endpoint.
  - `POST /character-api/auth/obr-guest`: body `{ "roomId": "<obrRoomId>" }`; returns `200` with `{ "ok": true, "roomId": "...", "expiresAt": "...", "deprecated": true }`. This endpoint is retained only for compatibility and no longer grants canonical OBR room write authority.
  - `POST /character-api/auth/obr-room-capability`: body `{ "roomId": "<obrRoomId>" }`; requires authenticated session plus `X-CSRF-Token` and returns `200` with `{ "ok": true, "roomId": "...", "expiresAt": "...", "capability": "<token>" }`. The returned capability is the intended short-lived auth primitive for canonical OBR room sync.
  - `POST /character-api/auth/password/request`: body `{ "email": "..." }`; responds `200` with `{ "ok": true }` even if the email is not known (to avoid leaking accounts). Errors (e.g., `invalid_email`, `email_failure`) return `{ "error": "<code>" }`.
  - `POST /character-api/auth/password/reset`: body `{ "token": "...", "newPassword": "..." }`; on success responds `{ "ok": true }` and revokes existing sessions; errors include `missing_fields`, `invalid_token`, or `validation_failed`.
  - `GET /character-api/auth/oauth/google`: without query params, redirects to Google OAuth when configured; if OAuth env keys are missing it returns `500` with `{ "error": "oauth_unconfigured" }`. With `?code=...` (callback) it exchanges tokens, finds/creates the linked user, issues a session (sets cookies), and then redirects back to the `state` URL if it matches `WS_BUILDER_URL`, otherwise falls back to `WS_BUILDER_URL`.
  - Legacy DB compatibility: if `users` is still a Laravel-style table (`id` bigint auto-increment, `password` column), signup/login/OAuth fallback paths now use that schema instead of requiring `password_hash` + UUID `id`.
- **Cookies / CSRF:** the API sets two cookies when a session exists: a **`ws_session`** http-only cookie containing a random 32-byte session token, and a non-HttpOnly **`ws_csrf`** cookie that mirrors the CSRF token. State-changing requests (`POST /auth/logout`, character `POST/PUT/DELETE`, etc.) require the `X-CSRF-Token` header to match the `ws_csrf` cookie. Cookies use `SameSite=Lax` and `Secure` when the request is over HTTPS, and `WS_COOKIE_DOMAIN` controls the domain scope.
- **Cookies / CSRF:** the API sets two cookies when a session exists: a **`ws_session`** http-only cookie containing a random 32-byte session token, and a non-HttpOnly **`ws_csrf`** cookie that mirrors the CSRF token. State-changing requests (`POST /auth/logout`, character `POST/PUT/DELETE`, etc.) require the `X-CSRF-Token` header to match the `ws_csrf` cookie. Cookies use `SameSite=None` with `Secure` on HTTPS so OBR embedded flows can include auth/CSRF cookies cross-site; on non-HTTPS local/test hosts they fall back to `SameSite=Lax` and omit forced cross-domain cookie scope so local auth regression tests remain valid.
- **Error responses:** all failures use `respond_error(...)` so the body is `{ "error": "<code>" }` with an optional `"details": [ ... ]` array for validation or conflict explanations; HTTP status codes reflect the failure (`400` for invalid inputs, `401`/`403` for auth issues, `409` for conflicts, `500` for server-side errors).

Canonical schema:
- `CharacterRecordV1` / `CharacterRecordV1Schema` in `@whisperspace/sdk` (source of truth).
- JSON schema file: `/hdd/sites/stuartpringle/whisperspace-sdk/schema/character-record.v1.json`
- Schema endpoint: `https://rules-api.whisperspace.com/character-api/schema.json`

Endpoints:
- `GET /character-api/health`
  - Returns `{ "ok": true }`.
- `GET /character-api/schema.json`
  - Returns JSON schema for `CharacterRecordV1`.
- `GET /character-api/characters`
  - Requires authenticated session (`ws_session` cookie).
  - Returns owner-scoped array of `{ id, name, updatedAt, visibility, tags }` for the current account only (admins still receive all records).
  - This endpoint does not include other users' public records; public sharing is handled by direct `GET /character-api/characters/:id`.
  - Enforcement is defense-in-depth: owner scoping is applied in query selection and re-checked before rows are emitted.
- `POST /character-api/characters`
  - Body: full character sheet. Generates `id` if missing.
  - Optional `?visibility=public|private` can override the default (body still accepts a `visibility` field; public visibility is persisted and returned on list/detail calls).
- `GET /character-api/characters/:id`
  - Returns full sheet.
  - Access policy: owner/admin always allowed; non-owners allowed only when character visibility is `public`.
- `PUT /character-api/characters/:id`
  - Body: full sheet. Uses `If-Unmodified-Since` to detect conflicts.
  - On conflict: `409` with `{ error: "conflict", current: <sheet> }`.
  - Visibility can also be forced via `?visibility=public|private`; this overrides both the saved value and any `visibility` field in the body.
- `DELETE /character-api/characters/:id`

OBR canonical instance endpoints (separate from Builder character records):
- `GET /character-api/obr-instance/:instanceId?roomId=:roomId`
  - Requires `X-WS-OBR-Room-Capability: <token>` for the matching room, or stronger server-side admin authorization.
  - Always returns `200` for a valid authorized request.
  - Returns `{ instanceId, roomId, updatedAt, found, sheet }`.
  - Misses return `{ found: false, updatedAt: null, sheet: null }` (no `404`), so OBR clients can treat missing canonical rows as normal cacheable misses without browser resource-error noise.
- `PUT /character-api/obr-instance/:instanceId?roomId=:roomId`
  - Body: `{ "sheet": <CharacterRecordV1-compatible object> }`
  - Upserts canonical OBR instance sheet for the room+instance key.
  - Write auth required: one of
    - valid `X-WS-OBR-Room-Capability: <token>` for the matching room, or
    - stronger server-side admin authorization.
- `DELETE /character-api/obr-instance/:instanceId?roomId=:roomId`
  - Removes canonical OBR instance sheet for the room+instance key.
  - Returns `{ ok: true }`.
  - Same auth requirement as `PUT`.

CORS for character-api:
- Origin allowlist is enforced when `Origin` header is present.
- Configure via `WS_CHARACTER_ALLOWED_ORIGINS` (comma-separated).
- Default allowlist: `https://whisperspace.com`, `https://www.whisperspace.com`, `https://builder.whisperspace.com`, `https://docs.whisperspace.com`, `https://developer.whisperspace.com`, `https://gm.whisperspace.com`, `https://obr.whisperspace.com`, `https://www.owlbear.rodeo`, `https://owlbear.rodeo`.
- `Access-Control-Allow-Headers` now includes core headers plus requested preflight headers (normalized), so OBR-specific auth headers are consistently accepted when configured.

Auth/session hygiene:
- Expired/revoked `obr_guest_sessions`, `obr_room_capabilities`, `user_sessions`, and stale `password_resets` rows are opportunistically cleaned during normal API traffic.
- Lightweight observability counters/logs are emitted for OBR guest issuance, room-capability issuance, and OBR instance write/delete outcomes; counters persist in temp storage (`/tmp/whisperspace_character_api_observability.json`) and sampled events are logged with `[ws][character-api]`.

Admin endpoints:
- `GET /character-api/admin/characters`
  - Returns `{ count, items: [{ id, name, created_at, updated_at }] }`.
- `DELETE /character-api/admin/characters?confirm=1`
  - Deletes all characters. Returns `{ ok: true, deleted }`.

Storage:
- MySQL is the default (via `DB_CONNECTION=mysql`). The API supports a UNIX socket via `DB_SOCKET`.
- SQLite support still exists for local/dev and always requires a valid `WS_CHARACTER_DB_PATH` that the PHP runtime can read/write.
- Keep character-API-specific settings in `/hdd/sites/stuartpringle/whisperspace-rules-api/.env` (copy the Postmark/mail fields from `/hdd/sites/stuartpringle/whisperspace/.env` instead of exposing a `/public/.env` file).

Schema override:
- `WS_CHARACTER_SCHEMA_PATH` (override schema file path).

Character sheet (v1) shape:
```json
{
  "id": "uuid",
  "name": "",
  "background": "",
  "motivation": "",
  "attributes": {
    "phys": 0,
    "ref": 0,
    "soc": 0,
    "ment": 0
  },
  "skills": {
    "athletics": 0
  },
  "stress": { "current": 0, "cuf": 0, "cufLoss": 0 },
  "wounds": { "light": 0, "moderate": 0, "heavy": 0 },
  "weapons": [],
  "armour": null,
  "inventory": [],
  "tags": ["npc", "campaign-alpha"],
  "notes": "",
  "createdAt": "",
  "updatedAt": "",
  "version": 1
}
```

Notes:
- Skill IDs are defined by `https://rules-api.whisperspace.com/rules-api/latest/skills.json`.
- Inventory item types: `item`, `cyberware`, `narcotics`, `hacker_gear`.

## Codex Audit Guardrails

Local operational files:
- `.codex/PROJECT-HISTORY.md` (gitignored): verbose milestone/task history.
- `.codex/AUDIT-LOG.md` (gitignored): local audit notes.
- `.codex/audits/*` (gitignored): raw batch/scheduled audit reports.

Workflow:
1. Make a change batch.
2. Review recent audit artifacts in `.codex/audits/` and `.codex/AUDIT-LOG.md`, then run `npm run codex:audit:status` for unresolved high/critical status.
3. Stage changes.
4. Commit (managed pre-commit runs fast checks; managed post-commit queues asynchronous Codex review for the new commit).
5. Run `npm run codex:audit:autoresolve` when explicitly resolving stale findings.
6. Resolve high/critical findings before merge.
7. Re-check with `npm run codex:audit:status` and log/report unresolved findings.

Script behavior:
- `codex-shared/pre-commit-managed.sh` runs fast checks only (`git diff --cached --check` + `audit-status`).
- `codex-shared/post-commit-managed.sh` queues asynchronous commit-scoped Codex audits after each commit.
- `codex-shared/post-commit-worker.sh` processes `.codex/audits/post-commit-queue.tsv` with a single lock-protected worker and validates lock ownership via PID plus `/proc` start-time checks before honoring an existing lock.
- `codex-shared/post-commit-review.sh <commit>` runs security/workflow/docs/contract review against a specific commit diff and writes report artifacts.
- `codex-shared/ci-post-commit-gate.sh` runs `post-commit-review.sh HEAD` and then enforces strict unresolved high/critical blocking for post-commit reports.
- `scripts/codex-batch-audit.sh --staged` audits staged diff and fails on high/critical findings.
- `scripts/codex-docs-audit.sh` audits staged diff specifically for required documentation updates (README/API/schema/auth/build docs).
- `scripts/codex-audit-status.sh` aggregates `.codex/audits/*` + `.codex/AUDIT-LOG.md` and fails when unresolved high/critical findings are older than one commit.
  - It also reports recent emergency bypass events from `.codex/BYPASS-LOG.tsv`.
- `scripts/codex-audit-autoresolve.sh` lists resolution candidates and writes `RESOLVED:` entries only for explicit `--resolve-key` values.
- `scripts/codex-orchestrate.sh` runs multiple Codex subprocess tasks from a tasks file with bounded concurrency and writes run artifacts to `.codex/orchestrator/run-<timestamp>/`.
- `scripts/codex-batch-audit.sh --working-tree --soft-fail` audits uncommitted edits without blocking.
- `scripts/codex-scheduled-audit.sh <days>` runs a periodic drift/security/docs audit over recent history.
- `scripts/claude-scheduled-audit.sh <days>` runs a scheduled ecosystem audit using Claude CLI and direct file-path context (AGENTS/README/PROJECT-OVERVIEW/PROJECT-SECURITY).
- `scripts/install-claude-audit-cron.sh <days>` installs/updates an idempotent user crontab entry for daily `claude:audit:repo` runs (logs to `.codex/audits/claude-scheduled-audit-cron.log`).
- `scripts/check-claude-audit-cron.sh` verifies the managed Claude audit cron block is present and correctly configured.
- `.github/workflows/codex-audit-status.yml` now runs the strict Codex post-commit gate in CI (required merge-time blocker when marked required).
- `scripts/install-codex-hooks-ecosystem.sh` installs a managed `.git/hooks/pre-commit` in each Whisperspace repo, preserving/chaining any existing hook as `pre-commit.user`; each managed hook calls the trusted root shared runtime in `/hdd/sites/whisperspace/codex-shared/pre-commit-managed.sh`.
- `scripts/sync-codex-ecosystem.sh` syncs AGENTS stubs + CI workflow + managed hooks across all Whisperspace repos, then verifies hook wiring.
- `WS_SKIP_POST_COMMIT_CODEX_AUDIT=1` skips queueing asynchronous Codex commit review (emergency-only).

Audit finding lifecycle note:
- `npm run codex:audit:autoresolve` lists candidate keys.
- Resolve explicitly with:
  - `bash scripts/codex-audit-autoresolve.sh --resolve-key '<severity|scope|issue>'`

## Current Status (2026-03-10)

Roadmap focus:
- `P0` release hardening complete in this repo: compatibility gate, contract smoke checks, and single-command orchestrator.
- `P1` shared-client convergence is complete for the primary active consumers; remaining work is normal maintenance to avoid reintroducing local shims.
- `P2` observability/docs normalization and codex-driven audit automation are in place; ongoing work is operational refinement rather than migration.

Progress on unfinished work:
- `ECO-004` (SDK-first contracts): complete at the ecosystem level; this repo now mainly needs to avoid reclaiming shared client behavior that belongs in `sdk`.
- `ECO-005` (platform client rollout): complete at the ecosystem level; readiness trackers remain useful as regression detectors, not migration trackers.
- `ECO-008` (codex/claude audit automation): complete at the ecosystem level; remaining work is operational polish and keeping ecosystem-wide policy sync current.
- Security audit coordination is in progress; high/critical findings from `PROJECT-SECURITY.md` should block promotion.

Operational notes:
- Google OAuth Redirect URI: `https://rules-api.whisperspace.com/character-api/auth/oauth/google`
- Suggested JS origins (if used): `https://builder.whisperspace.com`, `https://obr.whisperspace.com` (plus any local/dev origins in use).
- Use `.codex/PROJECT-HISTORY.md` for verbose local milestone history; keep this README integration-focused.

## Integration Checklist
- Public entrypoints (URLs) and environment variables.
- API endpoints or interfaces exposed to other repos.
- Schema/contract references and versions.
- Auth expectations (keys, cookies, tokens, headers).
- Build/publish commands and deployment steps.
- Local dev setup and dependencies.
- Known integration pitfalls or gotchas.

## Cross-Repo Improvement Backlog (2026-03-06)
This repo is the orchestration point for ecosystem releases. The following backlog is the active plan for improving whole-system manageability, maintainability, and efficiency.

Priority order:
1. `P0` enforce compatibility + contract verification + one release workflow.
2. `P1` move Builder/OBR/GM to shared SDK/platform client runtime paths.
3. `P2` standardize observability and keep overview docs concise/accurate.

### Epics Owned Or Coordinated Here
1. `ECO-001` compatibility matrix enforcement
   - Deliverables: machine-readable compatibility manifests + validator.
   - Acceptance: publish/release fails when declared versions are incompatible.
2. `ECO-002` contract smoke tests and post-deploy checks
   - Deliverables: automated endpoint/shape checks for rules/calc/character-api critical paths.
   - Acceptance: contract drift is detected automatically before/after deploy.
3. `ECO-003` single release orchestrator
   - Deliverables: one workflow (`ecosystem:release`) that runs parser sync, publish, and verification.
   - Acceptance: no manual multi-command release is required for standard updates.
4. `ECO-006` observability baseline
   - Deliverables: shared counters/log conventions + alerts for API/publish failures and retry storms.
   - Acceptance: root cause triage for ecosystem incidents is fast and repeatable.
5. `ECO-007` documentation normalization
   - Deliverables: concise `PROJECT-OVERVIEW.md` dashboard + per-repo detailed changelogs.
   - Acceptance: overview stays current, short, and operationally reliable.
6. `ECO-008` codex guardrail automation
   - Deliverables: per-batch codex subprocess audit + scheduled drift/security/docs audits.
   - Acceptance: high/critical audit findings block commit/release batches and drift signals are visible in local audit logs.

Coordination dependencies:
- `ECO-004` SDK-first contract adoption (owned by `whisperspace-sdk`, consumed by rules-api/builder/OBR).
- `ECO-005` shared platform client rollout (owned by `whisperspace-sdk`, integrated by builder/OBR/GM).

SDK readiness scaffold command:
```bash
npm run sdk:readiness
```
Uses `compatibility/sdk-readiness.json` plus repo manifests to validate SDK contract adoption progress markers.

Platform-client readiness scaffold command:
```bash
npm run platform:readiness
```
Uses `compatibility/platform-client-readiness.json` to track adoption status for `@whisperspace/sdk/platform-client`.

Execution note:
- Track progress in `PROJECT-OVERVIEW.md` under `Ecosystem Streamlining Backlog (2026-03-06)` and update status on every release batch.

## Codex MCP Prerequisites

Codex MCP servers are machine-level runtime config (`~/.codex`), not repo files.

Required MCPs for this repo:
- `playwright`

One-time install:
```bash
codex mcp add playwright -- npx -y @playwright/mcp@latest
```

Verify:
```bash
codex mcp list
codex mcp get playwright --json
```

Project check:
```bash
bash scripts/check-mcp.sh
```
