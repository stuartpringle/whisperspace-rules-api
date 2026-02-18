# Whisperspace Rules API

This repo hosts the shared rules API, calc endpoints, and core module used by Whisperspace clients.

Quick publish:
```bash
npm run rules:publish
```
`rules:publish` now includes the character ownership regression gate (`npm run test:character-auth`) before publish steps continue.
If needed for constrained environments where local port binding is unavailable, you can bypass this gate explicitly:
```bash
WS_SKIP_CHARACTER_AUTH_TEST=1 npm run rules:publish
```

Character API ownership regression:
```bash
npm run test:character-auth
```

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
- The character API loads only `/hdd/sites/stuartpringle/whisperspace-rules-api/.env`.
- Keep `/hdd/sites/stuartpringle/whisperspace-rules-api/.env` updated with:
  - `WS_CHARACTER_API_KEY` and optional overrides for `WS_CHARACTER_DB_PATH`/`WS_CHARACTER_SCHEMA_PATH`.
  - MySQL settings: `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_SOCKET` (if using UNIX socket), `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`.
  - `WS_COOKIE_DOMAIN` (e.g. `.whisperspace.com`) and `WS_BUILDER_URL` used in password-reset emails.
  - Mail/Postmark secrets: `POSTMARK_SERVER_TOKEN`, `MAIL_FROM`, `MAIL_REPLY_TO`, `MAIL_APP_NAME`.
  - Google OAuth hooks when enabled: `WS_OAUTH_GOOGLE_CLIENT_ID`, `WS_OAUTH_GOOGLE_CLIENT_SECRET`, `WS_OAUTH_GOOGLE_REDIRECT_URI`.
  - Keep Postmark/mail values in this file rather than exposing a public `.env`.

Auth (shared key):
- Set `WS_CHARACTER_API_KEY` inside `/hdd/sites/stuartpringle/whisperspace-rules-api/.env`.
- Clients still authenticate with `Authorization: Bearer <key>` or `?api_key=...`.

Auth endpoints:
- `POST /character-api/auth/signup`
- `POST /character-api/auth/login`
- `POST /character-api/auth/logout`
- `GET /character-api/auth/session`
- `POST /character-api/auth/password/request`
- `POST /character-api/auth/password/reset`
- `GET /character-api/auth/oauth/google`

Auth contract:
- **Request/response shapes:**
  - `POST /character-api/auth/signup` / `POST /character-api/auth/login`: body `{ "email": "...", "password": "..." }`. Successful responses return `201`/`200` with `{ "user": { "id": "<uuid>", "email": "<email>" } }`. Failures return `{ "error": "<code>" }` (e.g., `invalid_credentials`, `user_exists`, `validation_failed`).
  - `POST /character-api/auth/logout`: no body; responds `200` with `{ "ok": true }` and clears `ws_session`/`ws_csrf` cookies. Requires `X-CSRF-Token` header matching the `ws_csrf` cookie.
  - `GET /character-api/auth/session`: returns `200` with `{ "user": null }` when no session or `{ "user": { "id": "<uuid>", "email": "<email>" } }` when authenticated.
  - `POST /character-api/auth/password/request`: body `{ "email": "..." }`; responds `200` with `{ "ok": true }` even if the email is not known (to avoid leaking accounts). Errors (e.g., `invalid_email`, `email_failure`) return `{ "error": "<code>" }`.
  - `POST /character-api/auth/password/reset`: body `{ "token": "...", "newPassword": "..." }`; on success responds `{ "ok": true }` and revokes existing sessions; errors include `missing_fields`, `invalid_token`, or `validation_failed`.
  - `GET /character-api/auth/oauth/google`: without query params, immediately redirects the browser to Google’s OAuth consent page. With `?code=...` (callback) it exchanges tokens, finds/creates the linked user, issues a session (sets cookies), and then redirects back to the `state` URL if it matches `WS_BUILDER_URL`, otherwise falls back to `WS_BUILDER_URL`.
- **Cookies / CSRF:** the API sets two cookies when a session exists: a **`ws_session`** http-only cookie containing a random 32-byte session token, and a non-HttpOnly **`ws_csrf`** cookie that mirrors the CSRF token. State-changing requests (`POST /auth/logout`, character `POST/PUT/DELETE`, etc.) require the `X-CSRF-Token` header to match the `ws_csrf` cookie. Cookies use `SameSite=Lax` and `Secure` when the request is over HTTPS, and `WS_COOKIE_DOMAIN` controls the domain scope.
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
  - Returns owner-scoped array of `{ id, name, updatedAt }` for the current account only (admins still receive all records).
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
  - Returns `{ ok: true }`.

Admin endpoints:
- `GET /character-api/admin/characters`
  - Returns `{ count, items: [{ id, name, created_at, updated_at }] }`.
- `DELETE /character-api/admin/characters?confirm=1`
  - Deletes all characters. Returns `{ ok: true, deleted }`.

Storage:
- MySQL is the default (via `DB_CONNECTION=mysql`). The API supports a UNIX socket via `DB_SOCKET`.
- SQLite support still exists for local/dev, using `/hdd/sites/stuartpringle/whisperspace-character-builder/db/characters.sqlite` or `WS_CHARACTER_DB_PATH`.
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
  "notes": "",
  "createdAt": "",
  "updatedAt": "",
  "version": 1
}
```

Notes:
- Skill IDs are defined by `https://rules-api.whisperspace.com/rules-api/latest/skills.json`.
- Inventory item types: `item`, `cyberware`, `narcotics`, `hacker_gear`.

## Current Status (2026-02-12)

Goals worked on:
- Switch character API storage from SQLite to MySQL (using main site credentials).
- Remove dependency on `/hdd/sites/stuartpringle/whisperspace/.env`.
- Fix CORS headers in Apache to avoid `*` with credentials.
- Fix validation and MySQL compatibility issues encountered during rollout.
- Stabilize OAuth insert/update for Google login.

Completed:
- Character API now loads only `/hdd/sites/stuartpringle/whisperspace-rules-api/.env`.
- MySQL driver support added (with optional `DB_SOCKET`) and verified via PHP socket test.
- MySQL-compatible table creation and column/index checks.
- OAuth upsert uses MySQL `ON DUPLICATE KEY UPDATE`.
- Character API CORS headers restricted to allowed origins via `.htaccess` (`https://builder.whisperspace.com`, `https://obr.whisperspace.com`).
- Validation fix: empty object now allowed (avoids `skills must be an object` when `{}` decodes to `[]`).
- Read-time normalization: if stored `skills` is an empty list, API returns `{}`.
- Added `gameplayEffects` support for weapons/armour/items/feats contracts and calc endpoints.
- Calc endpoints now apply gameplay deltas to attributes, derived values, and skill/stat modifiers, and return applied `gameplayDeltas`.
- Added Compact Backpack gameplay effect support (`carrying_capacity+5`) in gear parsing/data flow.

In progress / remaining:
- Data cleanup (optional): migrate or normalize any existing records that stored `skills: []`.
- Confirm final DB name and migrate any legacy SQLite data if needed.
- Re-test OAuth end-to-end after Google console setup (JS origins + redirect URI).
- Expand downstream consumers (`whisperspace-character-builder`, OBR extension) to send equipped `gameplayEffects` consistently in calc payloads.

Operational notes:
- Google OAuth Redirect URI: `https://rules-api.whisperspace.com/character-api/auth/oauth/google`
- Suggested JS origins (if used): `https://builder.whisperspace.com`, `https://obr.whisperspace.com` (plus any local/dev origins in use).

## Integration Checklist
- Public entrypoints (URLs) and environment variables.
- API endpoints or interfaces exposed to other repos.
- Schema/contract references and versions.
- Auth expectations (keys, cookies, tokens, headers).
- Build/publish commands and deployment steps.
- Local dev setup and dependencies.
- Known integration pitfalls or gotchas.
