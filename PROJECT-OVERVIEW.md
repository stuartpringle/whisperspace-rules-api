# Whisperspace Project Overview

## Scope
Whisperspace is a multi-repo ecosystem for a TTRPG ruleset. The goal is to maintain a single source of truth for rules data and reuse it across apps and extensions (character builders, VTT integrations, docs, and developer tooling) without duplicating data.

All project directories live in `/hdd/sites/stuartpringle` on an Ubuntu server and are served via Apache2 where applicable.

## Repositories And Roles
- `whisperspace`
  - Public-facing website.
  - Statamic site.
  - URL: `https://whisperspace.com`
- `whisperspace-rules-api`
  - Rules API, character API, and calc endpoints for Whisperspace.
  - Primary API surface for apps and VTT extensions.
  - URL: `https://rules-api.whisperspace.com`
  - Key entrypoints: `https://rules-api.whisperspace.com/rules-api/latest` and `https://rules-api.whisperspace.com/character-api/`
- `whisperspace-obr-extension`
  - Owlbear.rodeo VTT extension.
  - URL: `https://obr.whisperspace.com`
- `whisperspace-character-builder`
  - Main character builder application.
  - URL: `https://builder.whisperspace.com`
- `whisperspace-developer`
  - Developer documentation for the API and extension workflows.
  - URL: `https://developer.whisperspace.com`
- `whisperspace-docs`
  - Public rules reference and search.
  - URL: `https://docs.whisperspace.com`
- `whisperspace-rules-parser`
  - Internal pipeline that pulls the master rules document from Google Docs and outputs normalized YAML for downstream use.
  - No public URL.
- `whisperspace-sdk`
  - Shared schema and utilities used by multiple projects (API validation, character record types, shared data model).
  - Consumed by the rules API and client apps to stay aligned on types and schema.
  - No public URL.

## Overall Objective
Create a modular ecosystem where rules data is authored once (in the master rules document) and propagated through a single pipeline to all apps, extensions, and documentation. This enables consistent updates and minimizes duplication.

Planned progression:
1. Launch the core character builder (`builder.whisperspace.com`).
2. Extend the builder into VTT integrations for Owlbear.rodeo, Foundry, and Roll20, each with its own character builder UX.
3. Embed rules reference directly inside each VTT.
4. Add bi-directional linking so characters can move between the main builder and VTTs with minimal friction.

## Rules Data Workflow (This Repo)
The canonical rules data is produced by the Rules Parser and published through this repo.

Workflow:
1. Run the parser to pull and normalize rules content.
2. Sync output into this repo.
3. Publish to the live API.

Quick publish rules in this repo:
```bash
npm run rules:publish
```

## Hosting Notes
All services run on an Ubuntu host and are served via Apache2. Public-facing endpoints are mapped to their corresponding subdomains listed above.

## Versioning And Compatibility Matrix
Track cross-repo compatibility here (update on releases):

| Date | Rules API Version | SDK Version | Character Builder Version | OBR Extension Version | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-02-11 | | | | | Initial matrix placeholder |

## Cross-Repo Release Checklist
Use this when rules or schemas change:

1. Update the master rules document.
2. Run `whisperspace-rules-parser` to regenerate YAML.
3. In `whisperspace-rules-api`, run `npm run rules:publish`.
4. Update `whisperspace-sdk` schema/types if the data model changed.
5. Update `whisperspace-character-builder` to align with new schema/fields.
6. Update VTT extensions (Owlbear, Foundry, Roll20) to align with new schema/fields.
7. Update `whisperspace-docs` and `whisperspace-developer` for any user-facing changes.
8. Verify API endpoints and schema endpoints on `rules-api.whisperspace.com`.

## Shared Contracts Index
Canonical contracts and where they live:

- Rules data (JSON): `https://rules-api.whisperspace.com/rules-api/latest/`
- Rules metadata: `https://rules-api.whisperspace.com/rules-api/latest/meta.json`
- Calc schemas: `https://rules-api.whisperspace.com/rules-api/calc/schemas/index.json`
- Character record schema (source of truth): `/hdd/sites/stuartpringle/whisperspace-sdk/schema/character-record.v1.json`
- Character schema endpoint: `https://rules-api.whisperspace.com/character-api/schema.json`

## Status Rollup (Fill In)
Use this section to keep a single-source, cross-repo status summary.

### whisperspace
- Current status: Production Statamic site is live at `https://whisperspace.com`, with newsletter functionality and reCAPTCHA-protected forms.
- Recent milestones:
- Upgraded to `anakadote/statamic-recaptcha:^3.0`.
- Added backward-compatible reCAPTCHA version mapping in `config/recaptcha.php` so legacy `RECAPTCHA_VERSION=3/2` env values continue to work with the addon’s new `enterprise|v3|v2` config expectations.
- Captured runtime integration notes in this repo’s `README.md` for future addon upgrades (cache clear + vendor publish steps).
- Applied frontend hardening pass: guarded hero-title animation script on templates that do not render `.animated-title`, aligned mobile/desktop nav CTA condition to `Get In Touch`, and removed stale JS references to legacy mobile menu IDs.
- Removed raw HTML injection risk in archetype cards by switching from Alpine `x-html` to `x-text` rendering for archetype descriptions.
- Next steps:
- Normalize `.env` to explicit string mode (`RECAPTCHA_VERSION=v3`) across environments during next deploy window.
- Keep reCAPTCHA addon/config publish steps in release runbook whenever Statamic addons are upgraded.

### whisperspace-rules-api
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-obr-extension
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-character-builder
- Current status: Production React/Vite builder is live at `https://builder.whisperspace.com` with rules-driven character creation, local drafts, and authenticated cloud save.
- Recent milestones:
- Added account UX polish in the Save dialog (clear login/signup/reset messaging and readable auth errors).
- Clarified save permissions in UI copy: `private` (just you) vs `public` (anyone).
- Save flow now uses staged modals (save menu -> auth when needed -> save options by target).
- Save options are conditional by target (only show `New copy` when an existing local/cloud record exists).
- Reset action now confirms and restores latest saved local/cloud copy when available.
- Began visual alignment with `whisperspace.com` (dark contact/footer treatment and starfield-inspired panel styling).
- Skills UX refresh: grouped/collapsible trees, search-by-name, no slug labels, compact +/- rank controls, and tooltip hints.
- Added inline SVG skill-group icons for attribute/focus trees.
- Added authenticated account menu under username with Character Builder / Character List / Settings / Log out actions.
- Implemented Character List page (search/sort/capacity slots/name-link/copy-link/edit, right-aligned numeric columns) with unsaved-change guard when switching edits.
- Enforced character-limit checks before creating new cloud/local copies.
- Added Settings page with account summary and persistent builder preferences.
- Hid empty character slots while list search filtering is active.
- Header/footer now use shared template rendering across builder/view/characters/settings pages.
- Back-to-builder button now appears under page title on non-builder pages.
- Added sort-direction indicators to Character List headers.
- Synced favicon assets from `whisperspace.com` into the character builder.
- Improved account menu hit-area sizing to resolve finicky hover/click behavior.
- Prototyped `augmented-ui` styling on builder shells (cards, tabs, modal cards, gear cards, primary CTAs).
- Increased augmented-ui prototype intensity for clearer visual comparison.
- Fixed OAuth/session cache behavior so stale cached null sessions do not mask fresh authenticated state after redirect.
- Added auth guard redirect from protected pages (`/characters`, `/settings`) to builder when logged out.
- Moved Previous/Next controls into the builder content card.
- Added drag-and-drop reordering for inventory and weapon cards.
- Increased vertical padding on gear cards for readability.
- Builder now persists the active tab across refresh; Back/Next controls moved near step tabs.
- Supports post-save redirect to shareable character view URL (`/character/:id`).
- Rules/skills/gear catalogs load from Rules API with local cache fallback messaging.
- Next steps:
- Add authenticated "My Characters" listing/management.
- Expand character view page with fuller derived stats and gear totals.
- Add manual rules-cache refresh control.

### whisperspace-developer
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-docs
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-rules-parser
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-sdk
- Current status:
- Recent milestones:
- Next steps:
