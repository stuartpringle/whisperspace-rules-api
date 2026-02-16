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
- Fixed inherited global Basic Auth prompt on `rules-api.whisperspace.com` root by adding a publish-root `.htaccess` override and wiring `rules:publish` to copy it into `dist/.htaccess`.

### whisperspace-obr-extension
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-character-builder
- Builder preview modals now present cleaned field labels (no raw IDs, pretty skill names) with two-column detail layout and improved selector action-row wrapping for `Preview` + `Buy` controls.
- Builder equipment selectors now expose `Preview` modals for weapons, armour, and gear entries so users can inspect full catalog detail before adding/buying.
- Builder armour action buttons were normalized to the same padded sizing as other row action controls for consistent touch/click targets.
- Builder credits adjustments are now handled via a dedicated modal flow (`Add/Remove`) launched from Equipment credits display, reducing control clutter in the gear summary row.
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
- Builder origin Motivation/Background dropdowns now sync default selection to current sheet values (including loaded sheets).
- Builder weapon ammo controls now enforce catalog max ammo caps; melee weapons without explicit ammo now show `-` and disable/hide reload/decrement actions.
- Builder drag/drop now includes drag-state polish and live hover reflow while dragging gear cards.
- Builder drag/drop hover reordering now includes jitter guards (rate-limit + per-target dedupe) to reduce flicker during rapid dragover events.
- Builder right-column account menu now includes `Save`/`Import`/`Reset` actions, uses full-email account labels, and no longer renders a menu container border.
- Builder header now consumes cross-project nav JSON from `whisperspace.com/nav/main-menu.v1.json` so top-level site navigation updates can propagate without duplicating link config.
- Builder derive polling now uses request-signature dedupe + in-flight guards to reduce calc rate-limit churn during debugging.
- Builder derive triggers are now constrained to relevant state changes (skills + gameplay-effect fields + key step entry + save), with explicit 429 cooldown backoff.
- Builder now pulls concept and starting-credits narrative lines directly from Rules API `rules.json` for the Origin step.
- Added starting credits generator + manual override in Origin; equipment summary now shows current credits balance.
- Inventory add now increments quantity when an equivalent gear entry already exists instead of creating duplicate rows.
- Builder + SDK schema now support multiple carried armour entries (`armours`) with a single equipped selector (`equippedArmourId`) while maintaining legacy `armour` compatibility.
- Builder now includes a modular dice-roller service with swappable providers (default CSS 3D roller), so roll UX can be replaced without changing character-sheet logic.
- Builder equipment UX now supports carried-armour card management (equip-highlight workflow) and a `Buy` vs `Acquire` mode that can enforce credits and auto-deduct catalog costs on add actions.
- Builder armour UX now matches weapon/item row patterns: each armour row expands for edits, and equip state only changes via explicit `Equip` action.
- Builder armour purchases now always create separate carried-armour instances (no merge) so durability can be tracked independently per piece.
- Builder equipment add controls now switch to `Buy ... (<cost> credits)` labels in buy mode and auto-disable when credits are insufficient (while `Acquire` mode retains standard add behavior).
- Builder buy-mode economy now supports sell semantics on gear controls (remove and item quantity decrement), while item quantity increment in buy mode performs affordability-checked purchases with credit deductions.
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
- Current status: Public rules docs frontend is a chapter-driven React/Vite rulebook at `https://docs.whisperspace.com`, consuming canonical `rules.json` chapter hierarchy with runtime version-aware caching and sanitized rich rendering.
- Recent milestones:
- Implemented searchable rulebook navigation with chapter routes and topic-level hash linking.
- Added query-aware chapter/topic navigation counts with search-order sorting (DESC by matches) and scoped in-topic term highlighting when navigating to a matched topic.
- Fixed docs search UX edge cases: chapter-click highlighting now scopes to the opened chapter by default, search mode hides `Rulebook Home`, and route normalization handles trailing-slash chapter URLs.
- Hardened docs Apache SPA fallback by adding `FallbackResource /index.html` + `-MultiViews` in docs `.htaccess` and documenting required vhost overrides for deep-link refresh reliability.
- Added docs URL query search contract (`?search=<term>`) so chapter routes can deep-link directly into active search context (e.g., `/stress?search=stress`).
- Implemented parser-span link rendering in docs so internal rules references navigate to mapped chapter/topic routes instead of inert text.
- Switched docs topic hashes to human-readable slug anchors (with legacy hash compatibility mapping) for clearer shareable links.
- Improved docs table readability by compacting parser-expanded adjacent duplicate cells into merged display columns (`colSpan`), fixing repeated header/body labels on archetype/feat tables.
- Updated docs sidebar navigation to nested chapter/topic tree behavior (indented sub-topic menu under active category), aligning docs UX with rulebook hierarchy.
- Added variable-marker anchor normalization in docs (`(X)`/`(n)` references resolve to base anchors like `#bleeding`, `#emp`, `#agonized`) for consistent intra-rule linking.
- Added parser-link contract fallback logic in docs: while parser contract is `#slug`/`file.yaml#slug`, current payload still includes some legacy `#h...` anchors, so docs resolves these via heading-text + singular/plural matching.
- Added parser span-style rendering support in docs so inline formatting (`bold`, `italic`, `underline`, `strikethrough`, and linked combinations) is visible in chapter content.
- Simplified docs reading surface by removing inner content card borders while retaining outer content container framing.
- Added docs sidebar scrollspy behavior so active nested topic highlighting follows reader scroll position within a chapter.
- Fixed docs scroll-lock regression by stabilizing location callbacks so hash auto-scroll does not re-trigger every render while manually scrolling.
- Added docs search toggle (`Hide empty categories`, default enabled) so zero-match chapter categories can be hidden during query-driven navigation.
- Extended the same toggle to nested chapter sub-topic trees so unchecking it reveals non-matching sub-topics for context while searching.
- Reworked `whisperspace-docs/src/lib/rules.js` to normalize canonical chapter/topic nodes (`title`, `slug`, `content`, `sections`) instead of heuristic flat extraction.
- Added recursive topic rendering in `whisperspace-docs/src/App.jsx` so rule text appears under its true parent topics.
- Added chapter alias routes for high-intent entry points (`/skills`, `/weapons`, `/items`, `/armour`, `/cyberware`, `/hacking-gear`).
- Enabled rich content rendering via markdown parse + sanitization (`marked` + `DOMPurify`) for paragraph/list text.
- Added client-side cache orchestration in `whisperspace-docs/src/lib/rulesClient.js`: fetch `meta.json`, compare version against cached payload, serve cached rules on version match, and refresh cache when version changes.
- Added automatic docs background version checks (interval-based) while runtime continues version-aware cache reuse.
- Added Apache SPA hosting support (`public/.htaccess`) with rewrite fallback + static asset caching policy.
- Expanded `whisperspace-docs/README.md` with concrete integration contracts: endpoint URLs, env var override (`VITE_RULES_URL`), auth/CORS expectations, build/deploy workflow, and known gotchas.
- Next steps:
- Validate production CORS + endpoint behavior for `https://docs.whisperspace.com` against `https://rules-api.whisperspace.com/rules-api/latest/rules.json` and `meta.json`.
- Add a lightweight release smoke test (rules fetch + parse count threshold) to catch upstream payload regressions early.

### whisperspace-rules-parser
- Current status:
- Recent milestones:
- Next steps:

### whisperspace-sdk
- Current status:
- Recent milestones:
- Next steps:
