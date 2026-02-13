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
- Added allowlist HTML sanitization for archetype descriptions before Alpine `x-html` rendering, preserving paragraph formatting while reducing DOM injection risk.
- Updated repo hygiene to ignore Statamic `users/` and stop tracking committed user account file(s) containing credential hashes.
- Improved frontend image delivery: compressed/width-bounded WebP Glide backgrounds, responsive archetype image `srcset`, lazy/async loading for below-the-fold images, and Apache cache headers for static assets.
- Added a repeatable image optimization script (`scripts/optimize-image-formats.sh`) and generated AVIF/WebP variants for key website assets; above-the-fold hero background/ship now use static AVIF/WebP with PNG fallback.
- Added AVIF transparency safeguards: skip AVIF generation for alpha-channel source images and use WebP+PNG fallback for the transparent hero ship asset.
- Refreshed website Rules section presentation: transformed markdown rule items into grouped card-grid UI with hover animation for better readability/scanability.
- Improved Archetypes section UX: preloaded carousel images for smoother transitions, stabilized image viewport sizing to reduce layout shift, and moved next/previous controls onto the image as overlay navigation buttons.
- Further Archetypes polish: thumbnails now render above the main image, description area uses fixed-height shell for stability, image-shell fallback uses themed gradient (not flat black), and edge nav/hover zoom interactions were refined.
- Archetypes interaction UX expanded: main image click now opens a framed modal view, edge nav controls were narrowed and intensified visually on hover, and description content width was increased for better visual alignment.
- About section UX refreshed: lead copy, "At a glance" bullets, and author details now render with section-specific card/callout styling on `https://whisperspace.com` while preserving CMS-managed markdown editing.
- Tuned website reCAPTCHA v3 to reduce false-positive bot flags across browser profiles by disabling page-load form gating and lowering threshold to `0.35`; cleared app caches after rollout.
- Updated website starfield rendering so the animated stars now persist across full-page scroll (global fixed canvas) with scroll-driven parallax drift instead of clipping at hero section bounds.
- Added shared navigation hosting on `whisperspace.com` via canonical JSON (`/nav/main-menu.v1.json`) with CORS headers so other Whisperspace subdomain apps can render the same top-level menu and compute active state consistently by host/path/hash.
- Fixed production Vite manifest lookup for shared navigation by adding `resources/js/shared-nav.js` to the Vite input list so deploy builds include it.
- Next steps:
- Normalize `.env` to explicit string mode (`RECAPTCHA_VERSION=v3`) across environments during next deploy window.
- Keep reCAPTCHA addon/config publish steps in release runbook whenever Statamic addons are upgraded.

### whisperspace-rules-api
- Current status: Rules + calc + character APIs are live, with MySQL-backed character storage stable and calc contracts now supporting equipment/feat `gameplayEffects` deltas.
- Recent milestones:
- Added `gameplayEffects` field support across weapons/armour/items/feats contracts in this repo.
- Updated calc derivation endpoints to apply gameplay deltas to attributes, derived stats, and skill modifiers (with floor-at-zero behavior for skill ranks).
- Compact Backpack and similar gear now map gameplay effects via programmatic text parsing from source rules wording (with explicit field override support).
- Published `skill_tooltips.json` in ID-keyed form (`skills.<skill_id>`, `attributes.<attribute_id>`) with label-keyed compatibility maps to unblock builder tooltip lookup.
- Expanded gameplay effect key normalization in calc parsing (aliases like `cuf` and `carryingCapacity` now resolve to canonical keys).
- README calc docs expanded with gameplay-effects contract and request/response examples.
- Next steps:
- Align builder + OBR payloads to always pass equipped gameplay effects into calc endpoints.
- Backfill gameplay effects for additional gear/feat entries as rules content is formalized.
- Clarify calc integration gotchas in downstream docs/clients (avoid double-counting gameplay effects from top-level lists + gear payloads).

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
- Refactored gear step order and grouping: Weapons, Armour, then Items.
- Added collapsed-by-default item/weapon rows with click-to-expand card details.
- Added explicit drag handles to item/weapon rows to make reorder interactions discoverable.
- Added compact item quantity controls and weapon ammo controls (minus/reload) in collapsed rows.
- Added gameplay-effects editor/tag UX for items, weapons, and armour (typed target + signed amount, removable chips).
- Updated catalog search so matching owned gear appears alongside rule-catalog results.
- Unified cut-corner panel spacing to shared 25px top/bottom padding treatment and strengthened destructive-button hover contrast.
- Added collapsed-row column headers for weapon/item readability and icon-based reload control.
- Updated gear search behavior to filter both catalog options and current inventory/weapon rows.
- Gameplay effect add forms now auto-close after creating an effect tag.
- Improved drag/reorder reliability with explicit HTML5 drag payload handling.
- Reordered builder step flow to mirror character-creation progression (`Origin`, `Archetype`, `Feats`, `Skills`, `Attributes`, `Equipment`, `Review`).
- Consolidated builder progression by merging `Skills` + `Attributes` into one step (`Skills & Attributes`) with attributes displayed first.
- Updated `Skills & Attributes` presentation with explicit section headers and metric cards (main attributes + CUF/Speed/Carrying Capacity).
- Added hover/visual polish on attribute cards and skill rows; tooltip display now resolves from Rules API tooltip labels with safer fallback behavior.
- Moved background controls into `Origin`; `Archetype` now renders narrative guidance text sourced from Rules API content.
- Builder now sends normalized gameplay effects into calc derive endpoints so effects like `reflex+1` influence displayed derived attributes.
- Builder now extracts narrative copy from direct `rules.json` text nodes and decouples tooltip fetch from skills fetch so missing tooltip payloads do not break skills UI.
- Gear reorder handles now use stronger HTML5 drag payload/drop parsing semantics for better browser compatibility.
- Character builder Review step now uses a polished dashboard-style layout aligned with the project’s updated visual language.
- Builder calc calls were aligned to current API contracts by sending full equipment context and tolerating updated derive response field variants.
- Builder now normalizes gameplay-effect tags into a top-level `gameplayEffects` array for derive endpoints and omits per-entity effect fields in derive payload objects for deployed calc compatibility.
- Builder temporarily exposed an in-app calc debug panel during gameplay-effects rollout; this panel has now been removed from the user-facing UI after deployment validation.
- Builder now displays gameplay-adjusted effective skill ranks (capped at rank 5) and adds cancel actions to gameplay-effect editors for gear.
- Builder cloud-save pipeline now strips non-schema `gameplayEffects` fields from persistence payloads (while preserving gameplay tags in active editor state post-save) to avoid character API `validation_failed` responses.
- Builder save-options copy now labels the checkbox `Save as new character`; the old tooltip-style `i` label was removed.
- Builder now preserves `Review` as the active tab on refresh and uses `Save` (instead of `Next`) as the final-step primary nav action.
- Builder gear reorder interactions now start from the weapon/item row area (drag anywhere) rather than requiring a dedicated drag handle.
- Builder skills now render a 0-5 pip indicator beside rank controls for faster visual rank scanning.
- Builder derive polling now uses request-signature dedupe + in-flight guards to reduce calc rate-limit churn during debugging.
- Builder derive triggers are now constrained to relevant state changes (skills + gameplay-effect fields + key step entry + save), with explicit 429 cooldown backoff.
- Builder now pulls concept and starting-credits narrative lines directly from Rules API `rules.json` for the Origin step.
- Added starting credits generator + manual override in Origin; equipment summary now shows current credits balance.
- Inventory add now increments quantity when an equivalent gear entry already exists instead of creating duplicate rows.
- Builder now persists the active tab across refresh; Back/Next controls moved near step tabs.
- Supports post-save redirect to shareable character view URL (`/character/:id`).
- Rules/skills/gear catalogs load from Rules API with local cache fallback messaging.
- Gameplay-effect tags are now aggregated into a top-level `gameplayEffects` array for calc endpoints; gear payloads are omitted to avoid double-counting.
- Next steps:
- Expand character view page with fuller derived stats and gear totals.
- Add manual rules-cache refresh control.
- Keep gameplay-effects calc payload/response contract notes synced across repos as rules/calc evolves.
- Ensure gear mapped from rules catalogs preserves `gameplayEffects` (or at least passes effect text) so calc endpoints can apply gameplay deltas consistently.

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
