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
- `https://whisperspace.com/rules-api/latest/`

Key files:
- `rules.json` (full rules tree)
- `skills.json`, `weapons.json`, `armour.json`, `items.json`, `cyberware.json`, `narcotics.json`, `hacking_gear.json`
- `weapon_keywords.json`, `skill_tooltips.json`
- `meta.json` (semver + hashes)

### Core Module (HTTP)

```js
import { buildAttackOutcome, deriveAttributesFromSkills } from "https://whisperspace.com/rules-api/latest/core/index.js";
```

### Calc Endpoints (PHP)

All endpoints are `POST` and accept JSON bodies. No auth required.
Rate limit: 120 requests per minute per IP (best-effort).
Schemas: `https://whisperspace.com/rules-api/calc/schemas/index.json`

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

## Character API (SQLite-backed)

Base URL:
- `https://whisperspace.com/character-api`

Auth (shared key):
- Set `WS_CHARACTER_API_KEY` in `/hdd/sites/stuartpringle/whisperspace/.env`.
- Clients send `Authorization: Bearer <key>` or `?api_key=...`.

Endpoints:
- `GET /character-api/health`
  - Returns `{ "ok": true }`.
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

Character sheet (v1) shape:
```json
{
  "id": "uuid",
  "name": "",
  "concept": "",
  "background": "",
  "level": 1,
  "attributes": {
    "phys": 0,
    "dex": 0,
    "int": 0,
    "will": 0,
    "cha": 0,
    "emp": 0
  },
  "skills": [
    { "key": "", "label": "", "rank": 0, "focus": "" }
  ],
  "gear": [
    { "id": "", "name": "", "type": "item", "tags": [], "notes": "" }
  ],
  "notes": "",
  "createdAt": "",
  "updatedAt": "",
  "version": 1
}
```
