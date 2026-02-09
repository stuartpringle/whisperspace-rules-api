# Whisperspace Rules API

This repo hosts the shared rules API, calc endpoints, and core module used by Whisperspace clients.

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
   PYTHONPATH=src python3 -m whisperspace_rules_parser.cli --out out
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
- `https://rules-api.whisperspace.com/latest/`

Key files:
- `rules.json` (full rules tree)
- `skills.json`, `weapons.json`, `armour.json`, `items.json`, `cyberware.json`, `narcotics.json`, `hacking_gear.json`
- `weapon_keywords.json`, `skill_tooltips.json`
- `meta.json` (semver + hashes)

### Core Module (HTTP)

```js
import { buildAttackOutcome, deriveAttributesFromSkills } from "https://rules-api.whisperspace.com/latest/core/index.js";
```

### Calc Endpoints (PHP)

All endpoints are `POST` and accept JSON bodies. No auth required.
Rate limit: 120 requests per minute per IP (best-effort).
Schemas: `https://rules-api.whisperspace.com/calc/schemas/index.json`

Endpoints:
- `/calc/attack`
- `/calc/crit-extra`
- `/calc/damage`
- `/calc/derive-attributes`
- `/calc/derive-cuf`
- `/calc/skill-notation`
- `/calc/skill-mod`
- `/calc/status-deltas`
- `/calc/status-apply`
- `/calc/ammo-max`
- `/calc/point-budget`
- `/calc/validate-sheet`

## Character API (SQLite-backed)

Base URL:
- `https://rules-api.whisperspace.com/character-api`

Auth (shared key):
- Set `WS_CHARACTER_API_KEY` in `/hdd/sites/stuartpringle/whisperspace/.env`.
- Clients send `Authorization: Bearer <key>` or `?api_key=...`.

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
  - Returns array of `{ id, name, updatedAt }`.
- `POST /character-api/characters`
  - Body: full character sheet. Generates `id` if missing.
- `GET /character-api/characters/:id`
  - Returns full sheet.
- `PUT /character-api/characters/:id`
  - Body: full sheet. Uses `If-Unmodified-Since` to detect conflicts.
  - On conflict: `409` with `{ error: "conflict", current: <sheet> }`.
- `DELETE /character-api/characters/:id`
  - Returns `{ ok: true }`.

Admin endpoints:
- `GET /character-api/admin/characters`
  - Returns `{ count, items: [{ id, name, created_at, updated_at }] }`.
- `DELETE /character-api/admin/characters?confirm=1`
  - Deletes all characters. Returns `{ ok: true, deleted }`.

Storage:
- SQLite default: `/hdd/sites/stuartpringle/whisperspace-character-builder/db/characters.sqlite`
- Override with `WS_CHARACTER_DB_PATH`.
- Sample env: `public/character-api/.env.example` (do not deploy as `.env`).

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
- Skill IDs are defined by `https://rules-api.whisperspace.com/latest/skills.json`.
- Inventory item types: `item`, `cyberware`, `narcotics`, `hacker_gear`.
